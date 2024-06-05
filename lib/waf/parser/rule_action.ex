defmodule Waf.Parser.RuleAction do
  use Ecto.Schema
  require Ecto.Query

  @primary_key false
  schema "rules_actions" do
    field(:rule_id, Ecto.UUID)
    field(:action_id, Ecto.UUID)
    belongs_to(:rule, Waf.Parser.Rule, define_field: false)
    belongs_to(:action, Waf.Parser.Action, define_field: false)
    field(:level, :integer)
  end


  def changeset(rule_action, params \\ %{}) do
    rule_action
    |> Ecto.Changeset.cast(params, [:rule_id, :action_id, :level], empty_values: [])
    |> Ecto.Changeset.validate_number(:level, greater_than: 0)
    |> Ecto.Changeset.validate_required([:rule_id, :action_id])
    |> Ecto.Changeset.unique_constraint([:rule_id, :action_id], name: :rules_actions_pkey)
  end

  def insert_all(_, _, actions_id_map) when actions_id_map == %{} do
    {:ok, []}
  end
  def insert_all(actions_params, rules_id_map, actions_id_map) do
    insert_results =
      actions_params
      |> Enum.map(
          &(
            %{
              rule_id: rules_id_map[%{rule_id: &1.rule_id, chain_level: &1.chain_level}],
              action_id: actions_id_map[%{name: &1.name, arg: &1.arg}],
              level: &1.level
            }
          )
        )
      |> Stream.map(&changeset(%Waf.Parser.RuleAction{}, &1))
      |> Enum.map(&Ecto.Changeset.apply_action(&1, :insert))


      # Qua devo dividere in 2: errori e corretti, devi ancora stampare gli errori
      #%{ok: validated_rules_actions, error: error_changesets} =
      insert_results = Enum.group_by(insert_results, &elem(&1, 0))
      validated_rules_actions = insert_results.ok
      error_changesets = Map.get(insert_results, :error)
      if !is_nil(error_changesets) do
        IO.inspect(error_changesets, label: "Rules actions errors")
      end

      rules_actions =
        validated_rules_actions
        |> Stream.map(&elem(&1, 1))
        |> Stream.map(&Map.from_struct/1)
        |> Enum.map(&Map.drop(&1, [:__meta__, :rule, :action]))


    output = Waf.Repo.insert_all(
      Waf.Parser.RuleAction,
      rules_actions,
      on_conflict: {:replace, [:level]},
      conflict_target: [:rule_id, :action_id]
    )

    {:ok, output}
  end
end
