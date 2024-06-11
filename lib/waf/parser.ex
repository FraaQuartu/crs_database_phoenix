defmodule Waf.Parser do
  @moduledoc """
  The Parser context.
  """

  import Ecto.Query, warn: false
  alias Waf.Repo

  alias Waf.Parser.Rule

  def list_rules(params) do
    IO.inspect(params, label: "Params")
    severity = Map.get(params, "severity", "")
    attack_type = Map.get(params, "attack_type", "")
    phase = Map.get(params, "phase", "")
    paranoia_level = Map.get(params, "paranoia_level", "")

    {min_phase, max_phase} = if phase == "", do: {0, 5}, else: {phase, phase}
    {min_paranoia_level, max_paranoia_level} = if paranoia_level == "", do: {0, 4}, else: {paranoia_level, paranoia_level}

    from(
      r in Waf.Parser.Rule,
      where: r.chain_level == ^1
      and ilike(r.severity, ^"%#{severity}%")
      and ilike(r.attack_type, ^"%#{attack_type}%")
      and r.phase >= ^min_phase and r.phase <= ^max_phase
      and r.paranoia_level >= ^min_paranoia_level and r.paranoia_level <= ^max_paranoia_level
    )
    |> Repo.all()
  end

  def get_rule!(id) do
    Repo.get!(Rule, id)
  end

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

  def delete_all() do
    from(r in Waf.Parser.Rule)
    |> Waf.Repo.delete_all()
  end

  def change_rule(%Rule{} = rule, attrs \\ %{}) do
    Rule.changeset(rule, attrs)
  end
end
