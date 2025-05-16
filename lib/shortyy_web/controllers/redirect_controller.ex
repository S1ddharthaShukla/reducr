defmodule ShortyyWeb.RedirectController do
  use ShortyyWeb, :controller
  alias Shortyy.LinkServer

  def show(conn, %{"short_id" => short_id}) do
    case LinkServer.get_long_url(short_id) do
      {:ok, long_url} ->
        conn
        |> put_resp_header("cache-control", "public, max-age=3600, immutable") 
        |> redirect(external: long_url)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: ShortyyWeb.ErrorHTML, template: "404.html") 
        |> render("404.html")

      {:error, _reason} -> 
        conn
        |> put_status(:internal_server_error)
        |> put_view(html: ShortyyWeb.ErrorHTML, template: "500.html")
        |> render("500.html")

    end
  end
end

