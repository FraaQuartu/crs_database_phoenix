defmodule Waf.Parser.Rule do
  use Ecto.Schema
  require Ecto.Query

  @primary_key false
  schema "rules" do
    field(:id, Ecto.UUID, primary_key: true, autogenerate: true)
    field(:rule_id, :integer)
    field(:chain_level, :integer)
    field(:rule_type, :string)
    field(:disruptive_action, :string)
    field(:severity, :string)
    field(:phase, :integer)
    field(:paranoia_level, :integer)
    field(:attack_type, :string)
    field(:file_name, :string)
    field(:inserted_at, :utc_datetime_usec)
    field(:rule_index, :integer)
    field(:operation_id, :string)
    many_to_many(:actions, Waf.Parser.Action, join_through: Waf.Parser.RuleAction, join_keys: [rule_id: :id, action_id: :id])
    many_to_many(:variables, Waf.Parser.Variable, join_through: Waf.Parser.RuleVariable, join_keys: [rule_id: :id, variable_id: :id])
    belongs_to(:operation, Waf.Parser.Operation, references: :id, foreign_key: :operation_id, define_field: false)
  end

  def changeset(rule, params \\ %{}) do
    now = DateTime.utc_now()
    id = Ecto.UUID.generate()

    rule
    |> Ecto.Changeset.cast(params,
      [
        :rule_id,
        :chain_level,
        :rule_type,
        :operation_id,
        :disruptive_action,
        :severity,
        :phase,
        :paranoia_level,
        :attack_type,
        :file_name,
        :rule_index
      ],
      empty_values: []
    )
    |> Ecto.Changeset.validate_number(:rule_id, greater_than: 0)
    |> Ecto.Changeset.validate_number(:chain_level, greater_than_or_equal_to: 1)
    |> Ecto.Changeset.validate_inclusion(:rule_type, ["SecRule", "SecAction"])
    |> Ecto.Changeset.validate_inclusion(:disruptive_action, ["allow", "block", "deny", "drop", "pass", "proxy", "redirect", ""])
    |> Ecto.Changeset.validate_inclusion(:severity, ["'CRITICAL'", "'ERROR'", "'NOTICE'", "'WARNING'", ""])
    |> Ecto.Changeset.validate_inclusion(:phase, 0..5)
    |> Ecto.Changeset.validate_inclusion(:paranoia_level, 0..4)
    # |> Ecto.Changeset.validate_required(:file_name)
    |> Ecto.Changeset.change(inserted_at: now)
    |> Ecto.Changeset.change(id: id)
    |> Ecto.Changeset.unique_constraint([:rule_id, :chain_level], name: :rules_ruleid_chainlevel)
  end

  # Prendo i parametri delle regole ed elimino tutte le regole con quegli id e chain_level
  def delete_all(rules_params) do
    # rule_id_map
    rules_id_list =
      Enum.reduce(rules_params, [],
      fn rule_params, id_list ->
        [rule_params.rule_id | id_list]
      end)

    output =
      Waf.Repo.delete_all(
        Ecto.Query.from(r in Waf.Parser.Rule, where: r.rule_id in ^(rules_id_list))
      )

    {:ok, output}
  end

  def insert_all(rules_params, operations_id_map) do
    insert_results =
      rules_params
      |> Stream.with_index()
      |> Stream.map(&Map.put(elem(&1,0), :rule_index, elem(&1,1)))
      |> Stream.map(&Map.put(&1, :operation_id, operations_id_map[&1.operation]))
      |> Stream.map(&Map.drop(&1, [:operation]))
      |> Stream.map(&changeset(%Waf.Parser.Rule{}, &1))
      |> Stream.map(&Ecto.Changeset.apply_action(&1, :insert))
      |> Enum.group_by(&elem(&1, 0))

    validated_rules = Map.get(insert_results, :ok, [])
    error_changesets = Map.get(insert_results, :error, [])
    if error_changesets != [] do
      IO.inspect(error_changesets, label: "Rules errors")
    end

    rules =
      validated_rules
      |> Stream.map(&elem(&1, 1))
      |> Stream.map(&Map.from_struct/1)
      |> Enum.map(&Map.drop(&1, [:__meta__, :operation, :actions, :variables]))

    Waf.Repo.insert_all(
      Waf.Parser.Rule,
      rules,
      on_conflict: {:replace, [:inserted_at]},
      conflict_target: [:rule_id, :chain_level]
    )

    inserted_rules =
      Ecto.Query.from(r in Waf.Parser.Rule, order_by: [desc: r.inserted_at], limit: ^(length(rules)))
      |> Waf.Repo.all()


    # Potrei ritornare qualcosa come
    # results = %{ok: [lista_di_ok], error: [lista_di_errors]}
    # {:ok, results}
    # così posso fare qualche verifica anche sugli errori
    {:ok, inserted_rules}
  end

  def get_id_map(inserted_rules) do
    id_map =
      Enum.reduce(inserted_rules, %{},
        fn
          inserted_rule, id_map ->
          Map.put(
            id_map,
            %{
              rule_id: inserted_rule.rule_id,
              chain_level: inserted_rule.chain_level
            },
            inserted_rule.id
            )
        end)

    {:ok, id_map}
  end
end
