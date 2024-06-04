defmodule Waf.Repo.Migrations.CreateActions do
  use Ecto.Migration

  def change do
    execute(&create_actions/0)
  end

  defp create_actions do
    query =
      "CREATE TABLE IF NOT EXISTS actions (
        id UUID PRIMARY KEY,
        name VARCHAR,
        arg VARCHAR,
        inserted_at TIMESTAMP NOT NULL
      )"

    action_unique_index = "
      CREATE UNIQUE INDEX IF NOT EXISTS actions_arg_name
      ON actions (name, arg)
      "

    repo().query!(query)
    repo().query!(action_unique_index)
  end
end
