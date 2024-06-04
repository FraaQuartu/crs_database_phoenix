defmodule WafWeb.RuleHTML do
  use WafWeb, :html

  embed_templates "rule_html/*"

  @doc """
  Renders a rule form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def rule_form(assigns)
end
