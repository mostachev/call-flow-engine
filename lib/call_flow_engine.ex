defmodule CallFlowEngine do
  @moduledoc """
  CallFlowEngine is a self-contained microservice for processing Asterisk call events
  and integrating with Bitrix24 CRM.

  ## Features

  - Connects to Asterisk via ARI (WebSocket + HTTP)
  - Processes call events (inbound/outbound)
  - Maintains call state and event log in PostgreSQL
  - Sends call data to Bitrix24 via REST API
  - Provides REST API for service status, statistics, and call history
  - Supports test event injection without real Asterisk

  ## Architecture

  The service consists of the following main components:

  - **ARI Connector** - Maintains WebSocket connection to Asterisk ARI
  - **Event Router** - Normalizes ARI events into internal format
  - **EventProcessor** - Processes events and maintains statistics
  - **Call Service** - Manages call lifecycle and state transitions
  - **Bitrix Client** - Handles integration with Bitrix24 CRM
  - **Phoenix API** - Provides REST endpoints for monitoring and testing
  """

  @doc """
  Returns the application version.
  """
  def version, do: Application.spec(:call_flow_engine, :vsn) |> to_string()
end
