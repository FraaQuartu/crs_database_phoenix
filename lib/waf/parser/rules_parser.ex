defmodule Waf.Parser.RulesParser do
  def parse_rules_from_file(file_path) do
    IO.puts("Loading rules from file #{file_path}")

    File.stream!(file_path)
    |> parse_rules(file_path)
  end

  def parse_rules_from_string(string) do
    string
    |> String.split("\n")
    |> parse_rules()
  end

  def parse_rules(rules, file_path \\ "") do

    ########### File parsing ###########
    rules_params =
      rules
      # Estraggo le regole
      |> Stream.map(&String.trim/1)
      |> Stream.map(&String.trim_trailing(&1, "\\"))
      # Elimino righe vuote
      |> Stream.reject(&(&1 == ""))
      |> Stream.reject(&String.starts_with?(&1, "#"))
      |> Enum.reduce({[], ""}, &process_line/2)
      |> finalize_rules()
      |> Stream.reject(&(String.starts_with?(&1, "SecMarker") || String.starts_with?(&1, "SecComponentSignature")))
      |> Enum.reverse()
      |> Stream.map(&split_rule/1)

      |> Enum.reduce({[], nil, 1},
        fn rules_params, {output, rule_id, chain_level} ->
          {rule, rule_id, chain_level} = extract_primary_fields(rules_params, rule_id, chain_level)
          {[rule | output], rule_id, chain_level}
        end
        )
      |> elem(0)
      |> Stream.map(&Map.put(&1, :file_name, file_path))

    ########### Split into 4 different lists for operations, rules, actions and variables ###########
    {operations, rules, actions, variables} =
      Enum.reduce(rules_params, {[], [], [], []},
        fn rule_params, {operations, rules, actions, variables} ->
          increment_lists(rule_params, {operations, rules, actions, variables})
        end)

    ########### Insert into database ###########
    Ecto.Multi.new()
    |> Ecto.Multi.run(:operations, fn _repo, _changes ->
      Waf.Parser.Operation.insert_all(operations)
    end)
    |> Ecto.Multi.run(:operations_id_map, fn _repo, changes ->
      Waf.Parser.Operation.get_id_map(changes.operations)
    end)
    |> Ecto.Multi.run(:delete_rules, fn _repo, _changes ->
      Waf.Parser.Rule.delete_all(rules)
    end)
    |> Ecto.Multi.run(:rules, fn _repo, changes ->
      Waf.Parser.Rule.insert_all(rules, changes.operations_id_map)
    end)
    |> Ecto.Multi.run(:rules_id_map, fn _repo, changes ->
      Waf.Parser.Rule.get_id_map(changes.rules)
    end)
    |> Ecto.Multi.run(:actions, fn _repo, _changes ->
      Waf.Parser.Action.insert_all(actions)
    end)
    |> Ecto.Multi.run(:actions_id_map, fn _repo, changes ->
      Waf.Parser.Action.get_id_map(changes.actions)
    end)
    |> Ecto.Multi.run(:rules_actions, fn _repo, changes ->
      Waf.Parser.RuleAction.insert_all(actions, changes.rules_id_map, changes.actions_id_map)
    end)
    |> Ecto.Multi.run(:variables, fn _repo, _changes ->
      Waf.Parser.Variable.insert_all(variables)
    end)
    |> Ecto.Multi.run(:variables_id_map, fn _repo, changes ->
      Waf.Parser.Variable.get_id_map(changes.variables)
    end)
    |> Ecto.Multi.run(:rules_variables, fn _repo, changes ->
      Waf.Parser.RuleVariable.insert_all(variables, changes.rules_id_map, changes.variables_id_map)
    end)
    |> Waf.Repo.transaction()
  end


  # Funzione eseguita dentro il reduce, per ricostruire le regole
  # Prima riga
  defp process_line(line, {[], ""}), do: {[], line}
  # Successive righe
  defp process_line(line, {previous_rules, new_rule}) do
    if String.starts_with?(line, "SecRule") or String.starts_with?(line, "SecAction") or String.starts_with?(line, "SecComponentSignature") or String.starts_with?(line, "SecMarker") do
      {[new_rule | previous_rules], line}
    else
      {previous_rules, new_rule <> line}
    end
  end
  # Ultima riga
  defp finalize_rules({rules, last_rule}) do
    [last_rule | rules]
  end

  # Split a rule into its primary fields, and return a map
  def split_rule(rule) do
    # Estraggo il tipo di regola (SecRule o SecAction)
    [rule_type, rest] = String.split(rule, " ", parts: 2)

    if rule_type == "SecAction" do
      actions =
        rest
        |> String.trim("\"")
        |> parse_actions()
      operation = %{operator: "", input_string: "", modifier: ""}
      %{rule_type: rule_type, actions: actions, operation: operation, variables: %{}}
    else
      # Estraggo gli args
      [variables, rest] = String.split(rest, " ", parts: 2)
      # variables = String.split(variables, "|")

      # Estraggo operation e actions
      rest =
          String.trim(rest, "\"")
          |> String.split("\" \"")

      # Qua devo considerare il caso in cui sia la seconda parte di una chain
      # e potrebbe non avere nessuna azione
      if length(rest) == 1 do
        [operation] = rest
        %{rule_type: rule_type, variables: parse_variables(variables), operation: parse_operation(operation), actions: []}
      else
        [operation, actions] = rest
        %{rule_type: rule_type, variables: parse_variables(variables), operation: parse_operation(operation), actions: parse_actions(actions)}
      end
    end
  end

  # From "act1:arg1,act2:arg2,actn:argn" to
  # [%{action: "act1", arg: "arg1"}, %{action: "act2", arg: "arg2"} ...]
  def parse_actions(actions) do
    # Regex che risolve il caso in cui l'arg abbia delle virgole, ad esempio
    # "tag:'a,b:c,d'"
    Regex.scan(~r/(?:[^:,]+:'[^']+')|(?:[^:,]+:[^:,]+)|(?:[^,:]+)/, actions)
    |> List.flatten()
    |> Enum.map(fn a ->
      name_and_arg = String.split(a, ":", parts: 2)
      name = Enum.at(name_and_arg, 0)
      arg = Enum.at(name_and_arg, 1, "")
      %{name: name, arg: arg}
    end)
  end

  # From "(mod1)collection1:member1|(mod2)collection2:member2|(modn)collectionn:membern" to
  # [%{modifier: mod1, collection: collection1, member: member2}, ...]
  def parse_variables(variables) do
    variables
    |> String.split("|")
    |> Map.new(fn v ->
        collection_and_member = String.split(v, ":")
        collection = Enum.at(collection_and_member, 0)
        member = Enum.at(collection_and_member, 1, "")
        {modifier, collection} =
          if String.at(collection, 0) in ["!", "&"] do
            String.split_at(collection, 1)
          else
            {"", collection}
          end

        {%{collection: collection, member: member}, modifier}
      end)
  end


  def parse_operation(operation) do
    operator_and_input_string = String.split(operation, " ", parts: 2)
    operator = Enum.at(operator_and_input_string, 0)
    input_string = Enum.at(operator_and_input_string, 1, "")

    {modifier, operator} =
      if String.at(operator, 0) == "!" do
        String.split_at(operator, 1)
      else
        {"", operator}
      end

    %{
      operator: operator,
      input_string: input_string,
      modifier: modifier
    }
  end

  # Stavolta salvo i parametri delle azioni come: %{azione1 => level1, azione2 => level2, azionen => leveln}
  # ossia %{%{name: name1, arg: arg1} => level1, %{name: name2, arg: arg2} => level2, %{name: namen, arg: argn} =>leveln}
  def extract_primary_fields(rule, rule_id, chain_level) do
    chain? = false
    action_level = 1
    actions = rule.actions

    output_rule =
      rule
      |> Map.put(:actions, %{})
      |> Map.put(:rule_id, rule_id)
      |> Map.put(:disruptive_action, "")
      |> Map.put(:severity, "")
      |> Map.put(:phase, 0)
      |> Map.put(:paranoia_level, 0)
      |> Map.put(:chain_level, chain_level)


    {output_rule, rule_id, _, chain?} =
    Enum.reduce(actions, {output_rule, rule_id, action_level, chain?},
      fn action, {output_rule, rule_id, action_level, chain?} ->
        # Controllo se l'azione è di uno dei tipi
        %{name: name, arg: arg} = action

        # Aggiungo la nuova azione alla regola
        cond do
          # id
          name == "id" ->
            {
              Map.put(output_rule, :rule_id, String.to_integer(arg)),
              String.to_integer(arg),
              action_level,
              chain?
            }
          # chain level
          name == "chain" ->
            {
              Map.put(output_rule, :chain_level, chain_level),
              rule_id,
              action_level,
              true
            }
          # Disruptive action
          name in ["allow", "block", "deny", "drop", "pass", "proxy", "redirect"] ->
            {
              Map.put(output_rule, :disruptive_action, name),
              rule_id,
              action_level,
              chain?
            }
          # Severity
          name == "severity" ->
            {
              Map.put(output_rule, :severity, arg),
              rule_id,
              action_level,
              chain?
            }
          # Paranoia level
          Regex.run(~r|paranoia-level/\d*|, arg) != nil ->
            [_match, paranoia_level] = Regex.run(~r|paranoia-level/(\d)|, arg)
            {
              Map.put(output_rule, :paranoia_level, String.to_integer(paranoia_level)),
              rule_id,
              action_level,
              chain?
            }
          # Attack type
          Regex.run(~r|'attack-.*|, arg) != nil ->
            [_match, attack_type] = Regex.run(~r|attack-(.*)|, arg)
            {
              Map.put(output_rule, :attack_type, String.trim(attack_type, "'")) ,
              rule_id,
              action_level,
              chain?
            }
          # Phase
          name == "phase" ->
            {
              Map.put(output_rule, :phase, String.to_integer(arg)),
              rule_id,
              action_level,
              chain?
            }
          true ->
            {
              Map.put(output_rule, :actions, Map.put(output_rule.actions, action, action_level)),
              rule_id,
              action_level + 1,
              chain?
            }
        end
      end)

    next_chain_level =
      if chain? do
        chain_level + 1
      else
        1
      end

    {output_rule, rule_id, next_chain_level}
  end

  defp increment_lists(rule_params, {operations, rules, actions, variables}) do
    new_operation =
      rule_params.operation

    new_rule =
      rule_params
      |> Map.drop([:actions, :variables])
      # :operation la tengo, perchè poi aggiungerò l'id

    actions_params = rule_params.actions
    new_actions =
      actions_params
      |> Map.keys()
      |> Stream.map(&Map.put(&1, :level, actions_params[&1]))
      |> Stream.map(&Map.put(&1, :rule_id, rule_params.rule_id))
      |> Enum.map(&Map.put(&1, :chain_level, rule_params.chain_level))

    variables_params = rule_params.variables
    new_variables =
      variables_params
      |> Map.keys()
      |> Stream.map(&Map.put(&1, :modifier, variables_params[&1]))
      |> Stream.map(&Map.put(&1, :rule_id, rule_params.rule_id))
      |> Enum.map(&Map.put(&1, :chain_level, rule_params.chain_level))

    {[new_operation | operations], [new_rule | rules], new_actions ++ actions, new_variables ++ variables}
  end

end
