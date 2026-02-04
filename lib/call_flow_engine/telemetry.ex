defmodule CallFlowEngine.Telemetry do
  @moduledoc """
  Telemetry event definitions and helper functions.
  
  ## Available Events
  
  ### Event Processing
  - `[:call_flow_engine, :event, :processed]` - event successfully processed
    - Measurements: `%{duration: integer()}` (nanoseconds)
    - Metadata: `%{event_type: string(), call_id: string()}`
  
  - `[:call_flow_engine, :event, :error]` - error processing event
    - Measurements: `%{count: 1}`
    - Metadata: `%{error: string(), event_type: string()}`
  
  ## Usage
  
  Subscribe to events:
  
      :telemetry.attach(
        "my-handler",
        [:call_flow_engine, :event, :processed],
        &MyModule.handle_event/4,
        nil
      )
  
  Or use TelemetryMetrics for Prometheus:
  
      Telemetry.Metrics.counter("call_flow_engine.event.processed.count"),
      Telemetry.Metrics.distribution("call_flow_engine.event.processed.duration")
  """

  require Logger

  @doc """
  Attaches default telemetry handlers for logging.
  Call this in Application.start/2 if you want console logging of metrics.
  """
  def attach_default_handlers do
    events = [
      [:call_flow_engine, :event, :processed],
      [:call_flow_engine, :event, :error]
    ]

    :telemetry.attach_many(
      "call-flow-engine-logger",
      events,
      &handle_event/4,
      nil
    )
  end

  @doc """
  Default telemetry handler that logs events.
  """
  def handle_event([:call_flow_engine, :event, :processed], measurements, metadata, _config) do
    duration_ms = measurements.duration / 1_000_000
    
    Logger.debug(
      "Event processed: #{metadata.event_type} for call #{metadata.call_id} in #{Float.round(duration_ms, 2)}ms"
    )
  end

  def handle_event([:call_flow_engine, :event, :error], _measurements, metadata, _config) do
    Logger.error("Event processing error: #{metadata.error} for type #{metadata.event_type}")
  end

  def handle_event(event, measurements, metadata, _config) do
    Logger.debug("Telemetry event: #{inspect(event)}, measurements: #{inspect(measurements)}, metadata: #{inspect(metadata)}")
  end
end
