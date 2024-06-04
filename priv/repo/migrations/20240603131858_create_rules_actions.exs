defmodule Waf.Repo.Migrations.CreateRulesActions do
  use Ecto.Migration

  def change do
    execute(&create_rules_actions/0)
  end

  defp create_rules_actions do
    query =
      "CREATE TABLE IF NOT EXISTS rules_actions (
        rule_id UUID
          REFERENCES rules(id)
          ON DELETE CASCADE,
        action_id UUID
          REFERENCES actions(id)
          ON DELETE CASCADE,
        level INTEGER,
        PRIMARY KEY(rule_id, action_id)
      )"


    repo().query!(query)
  end
end
