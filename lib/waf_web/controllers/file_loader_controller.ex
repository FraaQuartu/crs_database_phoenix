defmodule WafWeb.FileLoaderController do
  use WafWeb, :controller
  alias Waf.Parser

  def show(conn, _) do
    dic = %{}
    render(conn, :load_file, dic: dic)
  end

  def load(conn, %{"files" => files} = assigns) do
    IO.inspect(assigns)
    Enum.each(files, fn file ->
      file_path = file.path
      file_name = file.filename
      Parser.RulesParser.parse_rules_from_file(file_path, file_name)
    end)

    conn
    |> put_flash(:info, "Rules created successfully.")
    |> redirect(to: ~p"/rules")
  end
end
