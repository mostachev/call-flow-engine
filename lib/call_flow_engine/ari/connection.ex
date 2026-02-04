defmodule CallFlowEngine.Ari.Connection do
  @moduledoc """
  WebSocket client for Asterisk ARI.
  Maintains persistent connection and handles reconnection with exponential backoff.
  """

  use WebSockex
  require Logger

  @max_backoff 30_000

  def start_link(opts \\ []) do
    # Get config from opts (passed by supervisor) or fallback to Application env
    config = opts[:config] || Application.get_env(:call_flow_engine, :ari, [])
    
    url = Keyword.get(config, :url)
    user = Keyword.get(config, :user)
    password = Keyword.get(config, :password)
    app_name = Keyword.get(config, :app_name, "callflow_elixir")

    if is_nil(url) or is_nil(user) or is_nil(password) do
      Logger.warning("ARI configuration incomplete, starting in mock mode")
      # Start proper GenServer stub instead of unsupervised spawn
      GenServer.start_link(__MODULE__.MockMode, %{}, name: __MODULE__)
    else
      auth = Base.encode64("#{user}:#{password}")
      full_url = "#{url}?api_key=#{user}:#{password}&app=#{app_name}"
      
      headers = [{"Authorization", "Basic #{auth}"}]
      
      state = %{
        url: full_url,
        headers: headers,
        backoff: 1_000,
        app_name: app_name,
        reconnect_timer: nil
      }

      Logger.info("Starting ARI WebSocket connection to #{url}")
      WebSockex.start_link(full_url, __MODULE__, state, name: __MODULE__)
    end
  end

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("ARI WebSocket connected successfully")
    {:ok, %{state | backoff: 1_000}}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, event} ->
        Logger.debug("Received ARI event: #{event["type"]}")
        CallFlowEngine.Ari.EventRouter.route_event(event)
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to decode ARI event: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl true
  def handle_frame({:binary, _data}, state) do
    Logger.warning("Received unexpected binary frame from ARI")
    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("ARI WebSocket disconnected: #{inspect(reason)}")
    backoff = min(state.backoff * 2, @max_backoff)
    Logger.info("Will reconnect in #{backoff}ms...")
    
    # Cancel existing timer if any
    if state.reconnect_timer do
      Process.cancel_timer(state.reconnect_timer)
    end
    
    # Schedule reconnect without blocking the process
    timer = Process.send_after(self(), :reconnect, backoff)
    
    {:ok, %{state | backoff: backoff, reconnect_timer: timer}}
  end
  
  @impl true
  def handle_info(:reconnect, state) do
    Logger.info("Attempting to reconnect to ARI...")
    {:reconnect, %{state | reconnect_timer: nil}}
  end

  @impl true
  def handle_cast({:send, frame}, state) do
    {:reply, frame, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.warning("ARI Connection terminated: #{inspect(reason)}")
    :ok
  end
end
