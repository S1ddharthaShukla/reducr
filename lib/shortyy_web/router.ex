defmodule ShortyyWeb.Router do
  use ShortyyWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ShortyyWeb do
    pipe_through :api
    post "/links", LinkController, :create
  end

  # Route for redirection
  get "/:short_id", ShortyyWeb.RedirectController, :show
end
