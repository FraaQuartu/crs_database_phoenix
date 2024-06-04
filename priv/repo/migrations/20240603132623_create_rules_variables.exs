defmodule Waf.Repo.Migrations.CreateRulesVariables do
  use Ecto.Migration

  def change() do
    execute(&create_rules_variables/0)
  end

  defp create_rules_variables do
    query =
      "CREATE TABLE IF NOT EXISTS rules_variables (
        rule_id UUID
          REFERENCES rules(id)
          ON DELETE CASCADE,
        variable_id UUID
          REFERENCES variables(id)
          ON DELETE CASCADE,
        modifier CHAR(1),
        PRIMARY KEY (rule_id, variable_id)
      )"

    repo().query!(query)
  end
end
