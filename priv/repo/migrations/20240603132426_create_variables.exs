defmodule Waf.Repo.Migrations.CreateVariables do
  use Ecto.Migration

  def change do
    execute(&create_variables/0)
  end

  defp create_variables do
    query =
      "CREATE TABLE IF NOT EXISTS variables (
        id UUID PRIMARY KEY,
        collection VARCHAR,
        member VARCHAR,
        inserted_at TIMESTAMP NOT NULL
      )"

    variable_unique_index = "
      CREATE UNIQUE INDEX IF NOT EXISTS variables_collection_member
      ON variables (collection, member)
      "

    repo().query!(query)
    repo().query!(variable_unique_index)
  end
end
