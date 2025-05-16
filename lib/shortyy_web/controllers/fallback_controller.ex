defmodule ShortyyWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.
  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use ShortyyWeb, :controller

  # We've removed the Ecto.Changeset pattern match since we're not using Ecto
  # If you need validation error handling, we can use a different approach
  
  def call(conn, {:error, :validation_error, errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: errors})
  end
  
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: ShortyyWeb.ErrorHTML, template: "404.html")
    |> render("404.html")
  end
  
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
  end
  
  def call(conn, {:error, reason}) when is_atom(reason) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: Atom.to_string(reason)})
  end
  
  def call(conn, {:error, reason}) do
    IO.inspect(reason, label: "Fallback controller error")
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "Something went wrong"})
  end
end
