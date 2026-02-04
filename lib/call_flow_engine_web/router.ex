defmodule CallFlowEngineWeb.Router do
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CallFlowEngineWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  scope "/api", CallFlowEngineWeb do
    pipe_through :api

    get "/stats", StatsController, :index
    
    get "/calls", CallController, :index
    get "/calls/:id", CallController, :show
    
    post "/test/events", EventController, :create
  end
end
