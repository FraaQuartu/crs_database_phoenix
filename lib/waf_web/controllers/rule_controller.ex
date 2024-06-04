defmodule WafWeb.RuleController do
  use WafWeb, :controller

  alias Waf.Parser
  alias Waf.Parser.Rule
  import Ecto.Query

  def index(conn, _params) do
    rules = Parser.list_rules()
    render(conn, :index, rules: rules)
  end

  def new(conn, _params) do
    changeset = Parser.change_rule(%Rule{})
    render(conn, :new, changeset: changeset, conf: "")
  end

  def create(conn, %{"rule" => rule_params}) do
    rule_params["conf"]
    # Da fare: delega questa riga a Parser.create_rule()
    |> Parser.RulesParser.parse_rules_from_string()

    conn
    |> put_flash(:info, "Rule created successfully.")
    |> redirect(to: ~p"/rules")
    # Da fare: gestione di errori
  end

  def show(conn, %{"id" => id}) do
    rule = Parser.get_rule!(id)
    # Qui faccio la query di tutte le regole
    conf = Parser.FileGenerator.generate_conf([rule.rule_id])
    render(conn, :show, rule: rule, conf: conf)
  end

  def edit(conn, %{"id" => id}) do
    rule = Parser.get_rule!(id)
    changeset = Parser.change_rule(rule)
    conf = Waf.Parser.FileGenerator.generate_conf([rule.rule_id])
    render(conn, :edit, rule: rule, changeset: changeset, conf: conf)
  end

  def update(conn, %{"id" => id, "rule" => rule_params}) do
    rule = Parser.get_rule!(id)
    # Delete all
    Parser.delete_rules(rule.rule_id)

    # Create
    rule_params["conf"]
    |> Parser.RulesParser.parse_rules_from_string()

    conn
    |> put_flash(:info, "Rule updated successfully.")
    |> redirect(to: ~p"/rules")

  end

  def delete(conn, %{"id" => id}) do
    rule = Parser.get_rule!(id)
    {_n, nil} = Parser.delete_rules(rule.rule_id)

    conn
    |> put_flash(:info, "Rule deleted successfully.")
    |> redirect(to: ~p"/rules")
  end
end
