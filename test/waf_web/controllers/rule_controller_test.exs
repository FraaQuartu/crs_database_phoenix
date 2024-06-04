defmodule WafWeb.RuleControllerTest do
  use WafWeb.ConnCase

  import Waf.ParserFixtures

  @create_attrs %{rule_id: 42, chain_level: 42, rule_type: "some rule_type"}
  @update_attrs %{rule_id: 43, chain_level: 43, rule_type: "some updated rule_type"}
  @invalid_attrs %{rule_id: nil, chain_level: nil, rule_type: nil}

  describe "index" do
    test "lists all rules", %{conn: conn} do
      conn = get(conn, ~p"/rules")
      assert html_response(conn, 200) =~ "Listing Rules"
    end
  end

  describe "new rule" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/rules/new")
      assert html_response(conn, 200) =~ "New Rule"
    end
  end

  describe "create rule" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/rules", rule: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/rules/#{id}"

      conn = get(conn, ~p"/rules/#{id}")
      assert html_response(conn, 200) =~ "Rule #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/rules", rule: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Rule"
    end
  end

  describe "edit rule" do
    setup [:create_rule]

    test "renders form for editing chosen rule", %{conn: conn, rule: rule} do
      conn = get(conn, ~p"/rules/#{rule}/edit")
      assert html_response(conn, 200) =~ "Edit Rule"
    end
  end

  describe "update rule" do
    setup [:create_rule]

    test "redirects when data is valid", %{conn: conn, rule: rule} do
      conn = put(conn, ~p"/rules/#{rule}", rule: @update_attrs)
      assert redirected_to(conn) == ~p"/rules/#{rule}"

      conn = get(conn, ~p"/rules/#{rule}")
      assert html_response(conn, 200) =~ "some updated rule_type"
    end

    test "renders errors when data is invalid", %{conn: conn, rule: rule} do
      conn = put(conn, ~p"/rules/#{rule}", rule: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Rule"
    end
  end

  describe "delete rule" do
    setup [:create_rule]

    test "deletes chosen rule", %{conn: conn, rule: rule} do
      conn = delete(conn, ~p"/rules/#{rule}")
      assert redirected_to(conn) == ~p"/rules"

      assert_error_sent 404, fn ->
        get(conn, ~p"/rules/#{rule}")
      end
    end
  end

  defp create_rule(_) do
    rule = rule_fixture()
    %{rule: rule}
  end
end
