defmodule WafWeb.DeleteAllController do
  use WafWeb, :controller
  alias Waf.Parser

  def delete_all(conn, _) do
    Parser.delete_all()

    conn
    |> put_flash(:info, "Rules deleted successfully.")
    |> redirect(to: ~p"/rules")
  end
end
