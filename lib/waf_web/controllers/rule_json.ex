defmodule WafWeb.RuleJSON do
  alias Waf.Parser

  def show(%{rule_id: rule_id}) do
    Parser.FileGenerator.generate_json([rule_id])
  end

  def index(%{rules: rules}) do
    # Prendo tutti i rule_id
    rules
    |> Stream.map(fn rule -> rule.rule_id end)
    |> Enum.uniq()
    |> Parser.FileGenerator.generate_json()
  end
end
