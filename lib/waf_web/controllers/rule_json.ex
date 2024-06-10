defmodule WafWeb.RuleJSON do
  alias Waf.Parser.Rule
  import Ecto.Query

  def show(%{rule_id: rule_id}) do
    Waf.Parser.FileGenerator.generate_json([rule_id])
  end

  def index(%{}) do
    # Prendo tutti i rule_id
    rules_ids =
      from(
        r in Waf.Parser.Rule,
        select: r.rule_id,
        distinct: r.rule_id
      )
      |> Waf.Repo.all()
      |> Waf.Parser.FileGenerator.generate_json()
  end
end
