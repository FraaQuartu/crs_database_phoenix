defmodule WafWeb.RuleController do
  use WafWeb, :controller

  alias Waf.Parser
  alias Waf.Parser.Rule

  def index(conn, _params) do
    rules = Parser.list_rules()
    render(conn, :index, rules: rules)
  end

  def new(conn, _params) do
    changeset = Parser.change_rule(%Rule{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"rule" => rule_params}) do
    # Prendo la string del .conf
    # Faccio il parsing e inserisco
    # results =
      rule_params["conf"]
      # Da fare: delega questa riga a Parser.create_rule()
      |> Parser.RulesParser.parse_rules_from_string()

    conn
    |> put_flash(:info, "Rule created successfully.")
    |> redirect(to: ~p"/rules")

    # Da fare: gestione di errori
  end

  def show(conn, %{"id" => id}) do
    # conf = Waf.Parser.ConfGenerator.generate(id)
    rule = Parser.get_rule!(id)
    rule_id = rule.rule_id
    conf = Parser.FileGenerator.generate_conf(id_min: rule_id, id_max: rule_id)
    render(conn, :show, rule: rule, conf: conf)
  end

  def edit(conn, %{"id" => id}) do
    rule = Parser.get_rule!(id)
    changeset = Parser.change_rule(rule)
    render(conn, :edit, rule: rule, changeset: changeset)
  end

  def update(conn, %{"id" => id, "rule" => rule_params}) do
    rule = Parser.get_rule!(id)

    case Parser.update_rule(rule, rule_params) do
      {:ok, rule} ->
        conn
        |> put_flash(:info, "Rule updated successfully.")
        |> redirect(to: ~p"/rules/#{rule}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, rule: rule, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    rule = Parser.get_rule!(id)
    {:ok, _rule} = Parser.delete_rule(rule)

    conn
    |> put_flash(:info, "Rule deleted successfully.")
    |> redirect(to: ~p"/rules")
  end
end
