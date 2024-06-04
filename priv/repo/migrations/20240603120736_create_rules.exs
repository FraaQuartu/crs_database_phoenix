defmodule Waf.Repo.Migrations.CreateRules do
  use Ecto.Migration

  def change do
    execute(&create_rules/0)
  end

  defp create_rules do
    query =
      "CREATE TABLE IF NOT EXISTS rules (
        id UUID PRIMARY KEY,
        rule_id INTEGER,
        chain_level INTEGER,
        rule_type VARCHAR,
        severity VARCHAR,
        phase INTEGER,
        paranoia_level INTEGER,
        disruptive_action VARCHAR,
        attack_type VARCHAR,
        file_name VARCHAR,
        operation_id VARCHAR
          REFERENCES operations(id)
          ON DELETE CASCADE,
        inserted_at TIMESTAMP NOT NULL,
        rule_index INTEGER
      )"

      rule_unique_index = "
      CREATE UNIQUE INDEX IF NOT EXISTS rules_ruleid_chainlevel
      ON rules (rule_id, chain_level)
      "

      repo().query!(query)
      repo().query!(rule_unique_index)
  end

  # Devi prima migrare le operations, e poi le rules, e non viceversa!
end
