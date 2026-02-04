defmodule CallFlowEngine.Ari.Connection.MockMode do
  @moduledoc """
  Mock ARI connection for testing and development without real Asterisk.
  This is a proper GenServer that can be supervised.
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: CallFlowEngine.Ari.Connection)
  end

  @impl true
  def init(state) do
    Logger.info("ARI Connection running in mock mode (no real Asterisk connection)")
    {:ok, state}
  end

  @impl true
  def handle_call(_msg, _from, state) do
    {:reply, {:error, :mock_mode}, state}
  end

  @impl true
  def handle_cast(_msg, state) do
    {:noreply, state}
  end
end
