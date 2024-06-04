defmodule Waf.Parser.Action do
  use Ecto.Schema
  require Ecto.Query

  @primary_key false
  schema "actions" do
    field(:id, Ecto.UUID, primary_key: true, autogenerate: true)
    field(:name, :string)
    field(:arg, :string)
    field(:inserted_at, :utc_datetime_usec)
    many_to_many(:rules, Waf.Parser.Rule, join_through: Waf.Parser.RuleAction, join_keys: [action_id: :id, rule_id: :id])
  end

  def changeset(action, params \\ %{}) do
    now = DateTime.utc_now()
    id = Ecto.UUID.generate()

    action
    |> Ecto.Changeset.cast(params, [:name, :arg], empty_values: [])
    |> Ecto.Changeset.validate_required(:name)
    |> Ecto.Changeset.unique_constraint([:name, :arg], name: :actions_arg_name)
    |> Ecto.Changeset.change(inserted_at: now)
    |> Ecto.Changeset.change(id: id)
  end

  def insert_all([]) do
    {:ok, []}
  end

  def insert_all(actions_params) do
    insert_results =
      actions_params
      |> Stream.map(&Map.drop(&1, [:level, :rule_id, :chain_level]))
      |> Stream.uniq()
      |> Stream.map(&changeset(%Waf.Parser.Action{}, &1))
      |> Stream.map(&Ecto.Changeset.apply_action(&1, :insert))
      |> Enum.group_by(&(elem(&1, 0)))

    validated_actions = Map.get(insert_results, :ok)
    error_changesets = Map.get(insert_results, :error)
    if !is_nil(error_changesets) do
      IO.inspect(error_changesets, label: "Actions errors")
    end

    actions =
      validated_actions
      |> Stream.map(&elem(&1,1))
      |> Stream.map(&Map.from_struct/1)
      |> Enum.map(&Map.drop(&1, [:__meta__, :rules]))



    Waf.Repo.insert_all(
      Waf.Parser.Action,
      actions,
      on_conflict: {:replace, [:inserted_at]},
      conflict_target: [:name, :arg]
    )

    inserted_actions =
      Ecto.Query.from(a in Waf.Parser.Action, order_by: [desc: a.inserted_at], limit: ^(length(actions)))
      |> Waf.Repo.all()

    {:ok, inserted_actions}
  end

  def get_id_map([]) do
    {:ok, %{}}
  end
  def get_id_map(inserted_actions) do
    output =
      Enum.reduce(inserted_actions, %{},
        fn
          inserted_action, id_map ->
          Map.put(
            id_map,
            %{
              name: inserted_action.name,
              arg: inserted_action.arg
            },
            inserted_action.id
            )
        end)

    {:ok, output}
  end
end
