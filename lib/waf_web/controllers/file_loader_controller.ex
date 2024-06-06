defmodule WafWeb.FileLoaderController do
  use WafWeb, :controller
  alias Waf.Parser

  def show(conn, _) do
    dic = %{}
    render(conn, :load_file, dic: dic)
  end

  def load(conn, %{"files" => files}) do
    Enum.each(files, fn file ->
      file.path
      |> Parser.RulesParser.parse_rules_from_file()
    end)

    conn
    |> put_flash(:info, "Rules created successfully.")
    |> redirect(to: ~p"/rules")
  end
end
