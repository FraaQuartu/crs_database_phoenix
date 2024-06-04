defmodule Waf.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WafWeb.Telemetry,
      Waf.Repo,
      {DNSCluster, query: Application.get_env(:waf, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Waf.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Waf.Finch},
      # Start a worker by calling: Waf.Worker.start_link(arg)
      # {Waf.Worker, arg},
      # Start to serve requests, typically the last entry
      WafWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Waf.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WafWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
