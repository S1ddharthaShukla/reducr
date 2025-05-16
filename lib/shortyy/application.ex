defmodule Shortyy.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShortyyWeb.Telemetry,
      {Phoenix.PubSub, name: Shortyy.PubSub},
      ShortyyWeb.Endpoint,
      Shortyy.LinkServer 
    ]

    opts = [strategy: :one_for_one, name: Shortyy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ShortyyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

