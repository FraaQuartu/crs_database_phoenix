defmodule Waf.Parser.RuleVariable do
  use Ecto.Schema
  require Ecto.Query

  @primary_key false
  schema "rules_variables" do
    field(:rule_id, Ecto.UUID)
    field(:variable_id, Ecto.UUID)
    belongs_to(:rule, Waf.Parser.Rule, define_field: false)
    belongs_to(:variable, Waf.Parser.Variable, define_field: false)
    field(:modifier, :string)
  end

  def changeset(rule_variable, params \\ %{}) do
    rule_variable
    |> Ecto.Changeset.cast(params, [:rule_id, :variable_id, :modifier], empty_values: [])
    |> Ecto.Changeset.validate_inclusion(:modifier, ["", "!", "&"])
    |> Ecto.Changeset.validate_required([:rule_id, :variable_id])
    |> Ecto.Changeset.unique_constraint([:rule_id, :variable_id], name: :rules_variables_pkey)
  end

  def insert_all(variables_params, rules_id_map, variables_id_map) do
    insert_results =
      variables_params
      |> Enum.map(
          &(
            %{
              rule_id: rules_id_map[%{rule_id: &1.rule_id, chain_level: &1.chain_level}],
              variable_id: variables_id_map[%{collection: &1.collection, member: &1.member}],
              modifier: &1.modifier
            }
          )
        )

      |> Stream.map(&changeset(%Waf.Parser.RuleVariable{}, &1))
      |> Enum.map(&Ecto.Changeset.apply_action(&1, :insert))


      # Qua devo dividere in 2: errori e corretti, devi ancora stampare gli errori
      #%{ok: validated_rules_actions, error: error_changesets} =
      insert_results = Enum.group_by(insert_results, &elem(&1, 0))
      validated_rules_variables = insert_results.ok
      error_changesets = Map.get(insert_results, :error)
      if !is_nil(error_changesets) do
        IO.inspect(error_changesets, label: "Rules variables errors")
      end

      rules_variables =
        validated_rules_variables
        |> Stream.map(&elem(&1, 1))
        |> Stream.map(&Map.from_struct/1)
        |> Enum.map(&Map.drop(&1, [:__meta__, :rule, :variable]))

    output = Waf.Repo.insert_all(
      Waf.Parser.RuleVariable,
      rules_variables,
      on_conflict: {:replace, [:modifier]},
      conflict_target: [:rule_id, :variable_id]
    )

    {:ok, output}
  end
end
