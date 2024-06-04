defmodule Waf.Repo.Migrations.CreateOperations do
  use Ecto.Migration

  def change do
    execute (&create_operations/0)
  end

  def create_operations() do
    query =
      "CREATE TABLE IF NOT EXISTS operations (
        id VARCHAR PRIMARY KEY,
        operator VARCHAR,
        input_string VARCHAR,
        inserted_at TIMESTAMP NOT NULL,
        modifier CHAR(1)
      )"

    repo().query!(query)
  end
end
