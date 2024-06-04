defmodule Waf.Parser.FileGenerator do
  require Ecto.Query

    # Servirà comunque anche per la generazione di JSON o altri formati
    def query_rules(ids) do
      Ecto.Query.from(
        r in Waf.Parser.Rule,
        select: %{
          id: r.id,
          rule_id: r.rule_id,
          chain_level: r.chain_level,
          rule_type: r.rule_type,
          disruptive_action: r.disruptive_action,
          severity: r.severity,
          phase: r.phase,
          paranoia_level: r.paranoia_level,
          chain_length: over(count(r.id), :chain_length),
          operation_id: r.operation_id,
          inserted_at: r.inserted_at,
          rule_index: r.rule_index
          },
        windows: [chain_length: [partition_by: r.rule_id]],
        where: r.rule_id in ^ids,
        order_by: [r.inserted_at, r.rule_index]
      )
      |> Waf.Repo.all()
    end


  def generate_conf_file(file_name \\ "./rules/generated_rules/output_rules.conf", filters \\ []) do
    {:ok, file} = File.open(file_name, [:write])
    IO.binwrite(file, generate_conf(filters))
    File.close(file)
  end

  def generate_conf(filters \\ []) do

    ########## Queries ##########
    ids = Waf.Parser.Query.search_rules_ids_by_filters(filters)
    rules = query_rules(ids)

    # Altre info a per cui mi servirà un accesso efficiente
    # Per ogni rule mi servirà sapere il chain level e chain_length
    rules_info_map =
      Map.new(rules,
        fn rule ->
          {
            rule.id,
            %{
              rule_id: rule.rule_id,
              chain_level: rule.chain_level,
              chain_length: rule.chain_length,
              inserted_at: rule.inserted_at,
              rule_index: rule.rule_index
            }
          }
        end
      )
    rules_pk_ids =
      Enum.map(rules, &(&1.id))
    operations_ids =
      Enum.map(rules, &(&1.operation_id))

    variables = query_variables(rules_pk_ids)
    operations = query_operations(operations_ids)
    actions = query_actions(rules_pk_ids)

    ########## Output creation ##########
    # Rule type
    output_rules =
      Map.new(rules, &({&1.id, %{output_ruletype: &1.rule_type}}))

    # Variables
    output_rules =
      Enum.reduce(variables, output_rules,
        fn variable, output_rules ->
          rule_id = variable.rule_pk_id
          output_rule_map = output_rules[rule_id]

          # !!!!! Main part (rest is boilerplate)
          output_variables =
            Map.get(output_rule_map, :output_variables, "")
            <> (if variable.modifier == " ", do: "", else: variable.modifier)
            <> variable.collection
            <> (if variable.member != "", do: ":" <> variable.member, else: "")
            <> "|"
          # !!!!!

          output_rule_map = Map.put(output_rule_map, :output_variables, output_variables)
          Map.put(output_rules, variable.rule_pk_id, output_rule_map)
      end
    )
    # Remove the "|" inexcess at the end
    |> Map.new(
        fn {id, output_rule_map} ->
          output_variables = Map.get(output_rule_map, :output_variables, "")
          {
            id,
            Map.put(
              output_rule_map,
              :output_variables,
              String.trim_trailing(output_variables, "|")
            )
          }
        end
      )

    # Operations
    output_rules =
      Map.new(rules,
        fn rule ->
          rule_id = rule.id
          operation = operations[rule.operation_id]

          # !!!!! Main part
          output_operation =
            (if operation.modifier == " ", do: "", else: operation.modifier)
            <> operation.operator <> " "
            <> operation.input_string
          # !!!!!

          output_rule_map = Map.put(output_rules[rule_id], :output_operation, output_operation)
          {rule.id, output_rule_map}
      end
    )

    # Actions
    # Prima inserisco le action che sono già specificate nella table Rules
    output_rules =
      Enum.reduce(rules, output_rules,
        fn rule, output_rules ->

          # !!!!! Main part
          output_actions =
            if rule.chain_level == 1 do
              "id:#{rule.rule_id},\\\n    "
              <> "phase:#{rule.phase},\\\n    "
              <> "#{rule.disruptive_action},\\\n    "
            else
              ""
            end
            <> if(rule.severity != "", do: "severity:#{rule.severity},\\\n    ", else: "")
            <> if(rule.severity != "", do: "tag:'paranoia-level/#{rule.paranoia_level}',\\\n    ", else: "")
          # !!!!!

          output_rule_map = Map.put(output_rules[rule.id], :output_actions, output_actions)
          Map.put(output_rules, rule.id, output_rule_map)

        end
      )

    # Poi inserisco le action aggiuntive
    output_rules =
      Enum.reduce(actions, output_rules,
        fn action, output_rules->
          rule_id = action.rule_pk_id
          chain_level = rules_info_map[rule_id].chain_level
          output_rule_map = output_rules[rule_id]

          # !!!!! Main part
          output_actions =
            output_rules[rule_id].output_actions
            <> action.name
            <> (if action.arg == "", do: "", else: ":#{action.arg}")
            <> ",\\\n    "
            <> String.duplicate("    ", chain_level - 1)
          # !!!!!

            output_rule_map = Map.put(output_rule_map, :output_actions, output_actions)
            Map.put(output_rules, rule_id, output_rule_map)
        end
      )

    # E metto il "chain" alla fine
    output_rules =
      Enum.reduce(rules, output_rules,
        fn rule, output_rules ->
          # !!!!! Main part
          output_actions =
            output_rules[rule.id].output_actions
            <> if(rule.chain_level < rule.chain_length, do: "chain", else: "")
            |> String.trim_trailing()
            |> String.trim_trailing(",\\")
          # !!!!!

          output_rule_map = Map.put(output_rules[rule.id], :output_actions, output_actions)
          Map.put(output_rules, rule.id, output_rule_map)
        end
      )

    # Unisco tutte le 4 parti
    output_rules =
      Enum.map(output_rules,
        fn {rule_pk_id, %{output_ruletype: output_ruletype, output_variables: output_variables, output_operation: output_operation, output_actions: output_actions}} ->
          chain_level = rules_info_map[rule_pk_id].chain_level
          chain_length = rules_info_map[rule_pk_id].chain_length

          # !!!!! Main part
          output_string =
            String.duplicate("    ", chain_level - 1)
            <> output_ruletype <> " "
            <> (if output_ruletype == "SecRule", do: output_variables <> " " <> "\"" <> output_operation <> "\" ", else: "")
            <> "\\\n    " <> String.duplicate("    ", chain_level - 1)
            <> "\"" <> output_actions <> "\""
          # !!!!!

          inserted_at = rules_info_map[rule_pk_id].inserted_at
          rule_index = rules_info_map[rule_pk_id].rule_index
          # Inserted_at e rule_index servono per mantenere lo stesso ordine dei file da cui sono stati presi
          {inserted_at, rule_index, chain_level, chain_length, output_string}
        end
      )
      |> Enum.sort_by(&{elem(&1,0), elem(&1, 1)})

    # Infine restituisco la stringa
    Enum.reduce(output_rules, "",
      fn {_inserted_at, _rule_index, chain_level, chain_length, output_string}, output ->
        # IO.binwrite(file,
          output
          <> output_string <> "\n"
          <> (if chain_level == chain_length, do: "\n", else: "")
        # )
      end
    )

    # Enum.each(output_rules,
    #   fn {_inserted_at, _rule_index, chain_level, chain_length, output_string} ->
    #     IO.binwrite(file,
    #       output_string <> "\n"
    #       <> (if chain_level == chain_length, do: "\n", else: "")
    #     )
    #   end
    # )

  end

  # Output: list of %{rule_pk_id, modifier, collection, member}
  defp query_variables(rules_pk_ids) do
    Ecto.Query.from(
      v in Waf.Parser.Variable,
      join: rv in Waf.Parser.RuleVariable,
      on: v.id == rv.variable_id,
      select: %{
        rule_pk_id: rv.rule_id,
        modifier: rv.modifier,
        collection: v.collection,
        member: v.member
      },
      where: rv.rule_id in ^rules_pk_ids
    )
    |> Waf.Repo.all()
  end

  defp query_actions(rules_pk_ids) do
    Ecto.Query.from(
      a in Waf.Parser.Action,
      join: ra in Waf.Parser.RuleAction,
      on: a.id == ra.action_id,
      select: %{
        rule_pk_id: ra.rule_id,
        name: a.name,
        arg: a.arg
      },
      where: ra.rule_id in ^rules_pk_ids,
      order_by: ra.level
    )
    |> Waf.Repo.all()
  end

  # Output: %{id => %{modifier, operator, input_string}}
  defp query_operations(operations_ids) do
    Ecto.Query.from(
      o in Waf.Parser.Operation,
      select: {
        o.id,
        %{modifier: o.modifier, operator: o.operator, input_string: o.input_string}
      },
      where: o.id in ^operations_ids
    )
    |> Waf.Repo.all()
    |> Map.new()
  end


end
