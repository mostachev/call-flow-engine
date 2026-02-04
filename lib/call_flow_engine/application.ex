defmodule CallFlowEngine.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Repo
      CallFlowEngine.Repo,
      
      # Start the PubSub system
      {Phoenix.PubSub, name: CallFlowEngine.PubSub},
      
      # Start the Endpoint (http/https)
      CallFlowEngineWeb.Endpoint,
      
      # Start Task Supervisor for async tasks (Bitrix, etc)
      {Task.Supervisor, name: CallFlowEngine.TaskSupervisor},
      
      # Start Call Registry (ETS cache for active calls)
      CallFlowEngine.Calls.CallRegistry,
      
      # Start the EventProcessor GenServer
      CallFlowEngine.Events.EventProcessor,
      
      # Start the ARI WebSocket connection
      CallFlowEngine.Ari.Connection
    ]

    opts = [strategy: :one_for_one, name: CallFlowEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CallFlowEngineWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
