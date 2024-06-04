defmodule Waf.Parser.Query do
  require Ecto.Query

  # def search_rules_ids_by_filters(filters \\ []) do
  #   id_min = filters[:id_min] || 1
  #   id_max = filters[:id_max] || 1000000
  #   severity = filters[:severity] || ""
  #   paranoia_level_min = filters[:paranoia_level_min] || 0
  #   paranoia_level_max = filters[:paranoia_level_max] || 4
  #   attack_type = filters[:attack_type] || ""

  #   Ecto.Query.from(
  #     r in Waf.Parser.Rule,
  #     join: ra in Waf.Parser.RuleAction,
  #     on: r.id == ra.rule_id,
  #     join: a in Waf.Parser.Action,
  #     on: ra.action_id == a.id,
  #     where:
  #       r.rule_id >= ^id_min
  #       and r.rule_id <= ^id_max,
  #       and like(r.severity, ^"%#{severity}%")
  #       and r.paranoia_level >= ^paranoia_level_min
  #       and r.paranoia_level <= ^paranoia_level_max
  #       and a.name == ^"tag"
  #       and like(a.arg, ^"%#{attack_type}%"),
  #     select: r.rule_id,
  #     distinct: r.id
  #   )
  #   |> Waf.Repo.all()

  #   # Restituisco i rule_id, non le regole
  #   # altrimenti mancherebbero parti delle chain
  # end

  # def search_rules_by_filters(filters \\ []) do
  #   ids = search_rules_ids_by_filters(filters)

  #   Ecto.Query.from(
  #     r in Waf.Parser.Rule,
  #     where: r.rule_id in ^ids
  #   )
  #   |> Waf.Repo.all()
  # end
end
