defmodule Waf.ParserTest do
  use Waf.DataCase

  alias Waf.Parser

  describe "rules" do
    alias Waf.Parser.Rule

    import Waf.ParserFixtures

    @invalid_attrs %{rule_id: nil, chain_level: nil, rule_type: nil}

    test "list_rules/0 returns all rules" do
      rule = rule_fixture()
      assert Parser.list_rules() == [rule]
    end

    test "get_rule!/1 returns the rule with given id" do
      rule = rule_fixture()
      assert Parser.get_rule!(rule.id) == rule
    end

    test "create_rule/1 with valid data creates a rule" do
      valid_attrs = %{rule_id: 42, chain_level: 42, rule_type: "some rule_type"}

      assert {:ok, %Rule{} = rule} = Parser.create_rule(valid_attrs)
      assert rule.rule_id == 42
      assert rule.chain_level == 42
      assert rule.rule_type == "some rule_type"
    end

    test "create_rule/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Parser.create_rule(@invalid_attrs)
    end

    test "update_rule/2 with valid data updates the rule" do
      rule = rule_fixture()
      update_attrs = %{rule_id: 43, chain_level: 43, rule_type: "some updated rule_type"}

      assert {:ok, %Rule{} = rule} = Parser.update_rule(rule, update_attrs)
      assert rule.rule_id == 43
      assert rule.chain_level == 43
      assert rule.rule_type == "some updated rule_type"
    end

    test "update_rule/2 with invalid data returns error changeset" do
      rule = rule_fixture()
      assert {:error, %Ecto.Changeset{}} = Parser.update_rule(rule, @invalid_attrs)
      assert rule == Parser.get_rule!(rule.id)
    end

    test "delete_rule/1 deletes the rule" do
      rule = rule_fixture()
      assert {:ok, %Rule{}} = Parser.delete_rule(rule)
      assert_raise Ecto.NoResultsError, fn -> Parser.get_rule!(rule.id) end
    end

    test "change_rule/1 returns a rule changeset" do
      rule = rule_fixture()
      assert %Ecto.Changeset{} = Parser.change_rule(rule)
    end
  end
end
