defmodule ShortyyWeb.LinkController do
  use ShortyyWeb, :controller
  alias Shortyy.LinkServer
  action_fallback ShortyyWeb.FallbackController
  
  def create(conn, %{"long_url" => long_url}) do
    if String.trim(long_url) == "" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "long_url cannot be empty"})
    else
      case LinkServer.create_short_link(long_url) do
        {:ok, short_id} ->

          short_url = url(conn, ~p"/#{short_id}")
          
          conn
          |> put_status(:created)
          |> json(%{
            long_url: long_url,
            short_id: short_id,
            short_url: short_url 
          })
        {:error, reason} -> 
          IO.inspect(reason, label: "Link creation error from GenServer")
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "An unexpected error occurred creating link."})     
      end
    end
  end
  
  def create(conn, _params) do 
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing 'long_url' parameter"})
  end
end
