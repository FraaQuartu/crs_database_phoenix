defmodule Waf.Parser.Variable do
  use Ecto.Schema
  require Ecto.Query

  @primary_key false
  schema "variables" do
    field(:id, Ecto.UUID, primary_key: true, autogenerate: true)
    field(:collection, :string)
    field(:member, :string)
    field(:inserted_at, :utc_datetime_usec)
    many_to_many(:rules, Waf.Parser.Rule, join_through: Waf.Parser.RuleVariable, join_keys: [variable_id: :id, rule_id: :id])
  end

  def changeset(variable, params \\ %{}) do
    now = DateTime.utc_now()
    id = Ecto.UUID.generate()

    variable
    |> Ecto.Changeset.cast(params, [:collection, :member], empty_values: [])
    |> Ecto.Changeset.validate_required(:collection)
    |> Ecto.Changeset.unique_constraint([:collection, :member], name: :variables_collection_member)
    |> Ecto.Changeset.change(inserted_at: now)
    |> Ecto.Changeset.change(id: id)
  end

  def insert_all(variables_params) do
    insert_results =
      variables_params
      |> Stream.map(&Map.drop(&1, [:modifier, :rule_id, :chain_level]))
      |> Stream.uniq()
      |> Stream.map(&changeset(%Waf.Parser.Variable{}, &1))
      |> Stream.map(&Ecto.Changeset.apply_action(&1, :insert))
      |> Enum.group_by(&elem(&1, 0))

    validated_variables = Map.get(insert_results, :ok)
    error_changesets = Map.get(insert_results, :error)
    if !is_nil(error_changesets) do
      IO.inspect(error_changesets, label: "Variables errors")
    end

    variables =
      validated_variables
      |> Stream.map(&elem(&1,1))
      |> Stream.map(&Map.from_struct/1)
      |> Enum.map(&Map.drop(&1, [:__meta__, :rules]))

    Waf.Repo.insert_all(
      Waf.Parser.Variable,
      variables,
      on_conflict: {:replace, [:inserted_at]},
      conflict_target: [:collection, :member]
    )

    inserted_variables =
      Ecto.Query.from(v in Waf.Parser.Variable, order_by: [desc: v.inserted_at], limit: ^(length(variables)))
      |> Waf.Repo.all()

    {:ok, inserted_variables}
  end

  def get_id_map(inserted_variables) do
    output =
      Enum.reduce(inserted_variables, %{},
        fn
          inserted_variable, id_map ->
          Map.put(
            id_map,
            %{
              collection: inserted_variable.collection,
              member: inserted_variable.member
            },
            inserted_variable.id
            )
        end)
    {:ok, output}
  end
end
