defmodule CallFlowEngine.Ari.EventRouter do
  @moduledoc """
  Routes and normalizes ARI events into CallEventPayload structures.
  Extracts call_id, determines direction, and passes to EventProcessor.
  """

  require Logger
  alias CallFlowEngine.Events.{CallEventPayload, EventProcessor}

  @doc """
  Routes a raw ARI event to the event processor.
  """
  def route_event(raw_event) when is_map(raw_event) do
    try do
      payload = normalize_event(raw_event)
      EventProcessor.process_event(payload)
    rescue
      e ->
        Logger.error("Error routing ARI event: #{inspect(e)}")
        Logger.error("Raw event: #{inspect(raw_event)}")
    end
  end

  @doc """
  Normalizes a raw ARI event into a CallEventPayload.
  """
  def normalize_event(raw_event) do
    event_type = normalize_event_type(raw_event["type"])
    channel = get_in(raw_event, ["channel"])
    
    call_id = extract_call_id(raw_event)
    direction = determine_direction(raw_event)
    state = get_in(channel, ["state"])
    
    %CallEventPayload{
      call_id: call_id,
      event_type: event_type,
      direction: direction,
      channel: get_in(channel, ["name"]),
      caller_number: extract_caller_number(raw_event),
      callee_number: extract_callee_number(raw_event),
      state: state,
      raw_payload: raw_event,
      occurred_at: extract_timestamp(raw_event)
    }
  end

  # Extract call_id with priority: linkedid -> uniqueid -> channel id
  defp extract_call_id(event) do
    channel = get_in(event, ["channel"])
    
    cond do
      linked_id = get_in(channel, ["linkedid"]) -> linked_id
      unique_id = get_in(channel, ["id"]) -> unique_id
      channel_name = get_in(channel, ["name"]) -> channel_name
      true -> "unknown-#{:erlang.unique_integer([:positive])}"
    end
  end

  # Determine call direction based on variables and context
  defp determine_direction(event) do
    channel = get_in(event, ["channel"])
    variables = get_in(channel, ["channelvars"]) || %{}
    context = get_in(channel, ["dialplan", "context"]) || ""
    
    cond do
      Map.has_key?(variables, "intNum") -> :outbound
      Map.has_key?(variables, "extNum") -> :inbound
      String.contains?(context, "from-internal") -> :outbound
      String.contains?(context, "from-external") -> :inbound
      true -> :unknown
    end
  end

  # Extract caller number from various ARI fields
  defp extract_caller_number(event) do
    channel = get_in(event, ["channel"])
    
    get_in(channel, ["caller", "number"]) ||
      get_in(channel, ["caller", "name"]) ||
      get_in(channel, ["channelvars", "CALLERID(num)"])
  end

  # Extract callee number from various ARI fields
  defp extract_callee_number(event) do
    channel = get_in(event, ["channel"])
    
    get_in(channel, ["dialplan", "exten"]) ||
      get_in(channel, ["connected", "number"]) ||
      get_in(channel, ["channelvars", "EXTEN"])
  end

  # Extract timestamp from event
  defp extract_timestamp(event) do
    case get_in(event, ["timestamp"]) do
      nil -> DateTime.utc_now()
      timestamp when is_binary(timestamp) ->
        case DateTime.from_iso8601(timestamp) do
          {:ok, dt, _offset} -> dt
          _ -> DateTime.utc_now()
        end
      _ -> DateTime.utc_now()
    end
  end

  # Normalize ARI event type to internal format
  defp normalize_event_type("StasisStart"), do: "stasis_start"
  defp normalize_event_type("StasisEnd"), do: "stasis_end"
  defp normalize_event_type("ChannelStateChange"), do: "state_change"
  defp normalize_event_type("ChannelDestroyed"), do: "channel_destroyed"
  defp normalize_event_type("ChannelVarset"), do: "var_set"
  defp normalize_event_type("BridgeEnter"), do: "bridge_enter"
  defp normalize_event_type(other), do: String.downcase(other || "unknown")
end
