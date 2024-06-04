defmodule Waf.Parser.Operation do
  use Ecto.Schema
  require Ecto.Query

  @primary_key false
  schema "operations" do
    field(:id, :string, primary_key: true)
    field(:operator, :string)
    field(:modifier, :string)
    field(:input_string, :string)
    field(:inserted_at, :utc_datetime_usec)
    has_many(:rules, Waf.Parser.Rule, foreign_key: :operation_id, references: :id)
  end

  def changeset(operation, params \\ %{}) do
    now = DateTime.utc_now()
    id =
      # then()
      :crypto.hash(:sha256, Jason.encode!(params))
      |> Base.encode16()
      |> String.downcase()

    operation
    |> Ecto.Changeset.cast(params, [:operator, :input_string, :modifier], empty_values: [])
    |> Ecto.Changeset.validate_inclusion(:modifier, ["", "!"])
    |> Ecto.Changeset.change(inserted_at: now)
    |> Ecto.Changeset.change(id: id)
    |> Ecto.Changeset.unique_constraint([:id])
  end

  def insert_all(operations_params) do
    insert_results =
      operations_params
      |> Stream.uniq()
      |> Stream.map(&changeset(%Waf.Parser.Operation{}, &1))
      |> Stream.map(&Ecto.Changeset.apply_action(&1, :insert))
      |> Enum.group_by(&elem(&1, 0))

    validated_operations = Map.get(insert_results, :ok)
    error_changesets = Map.get(insert_results, :error)
    if !is_nil(error_changesets) do
      IO.inspect(error_changesets, label: "Operations errors")
    end

    operations =
      validated_operations
      |> Stream.map(&elem(&1, 1))
      |> Stream.map(&Map.from_struct/1)
      |> Enum.map(&Map.drop(&1, [:__meta__, :rules]))

    Waf.Repo.insert_all(
      Waf.Parser.Operation,
      operations,
      on_conflict: {:replace, [:inserted_at]},
      conflict_target: [:id]
    )

    inserted_operations =
      Ecto.Query.from(o in Waf.Parser.Operation, order_by: [desc: o.inserted_at], limit: ^(length(operations)))
      |> Waf.Repo.all()

    {:ok, inserted_operations}
  end

  # Prendo una lista di operazioni, e creo una map degli id del tipo:
  # %{op1 => id1, op2 => id2, opn => idn}
  def get_id_map(inserted_operations) do
    id_map =
      Enum.reduce(inserted_operations, %{},
        fn
          inserted_operation, id_map ->
          Map.put(
            id_map,
            %{
              operator: inserted_operation.operator,
              input_string: inserted_operation.input_string,
              # Per qualche motivo quando faccio la query
              # "" è trasformato in " "
              modifier:
                if inserted_operation.modifier == " " do
                  ""
                else
                  inserted_operation.modifier
                end
            },
            inserted_operation.id
            )
        end)
    {:ok, id_map}
  end
end
