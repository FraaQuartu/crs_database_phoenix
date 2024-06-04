defmodule Waf.ParserFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Waf.Parser` context.
  """

  @doc """
  Generate a rule.
  """
  def rule_fixture(attrs \\ %{}) do
    {:ok, rule} =
      attrs
      |> Enum.into(%{
        chain_level: 42,
        rule_id: 42,
        rule_type: "some rule_type"
      })
      |> Waf.Parser.create_rule()

    rule
  end
end
