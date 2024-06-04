defmodule Waf.Parser do
  @moduledoc """
  The Parser context.
  """

  import Ecto.Query, warn: false
  alias Waf.Repo

  alias Waf.Parser.Rule

  def list_rules do
    from(
      r in Waf.Parser.Rule,
      where: r.chain_level == ^1
    )
    |> Repo.all()
  end

  def get_rule!(id) do
    Repo.get!(Rule, id)
  end

  # def create_rule(attrs) do

  # end

  def update_rule(%Rule{} = rule, attrs) do
    rule
    |> Rule.changeset(attrs)
    |> Repo.update()
  end

  def delete_rules(rule_id) do
    from(
      r in Waf.Parser.Rule,
      where: r.rule_id == ^rule_id)
    |> Waf.Repo.delete_all()
  end

  def change_rule(%Rule{} = rule, attrs \\ %{}) do
    Rule.changeset(rule, attrs)
  end
end
