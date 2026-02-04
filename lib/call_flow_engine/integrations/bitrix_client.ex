defmodule CallFlowEngine.Integrations.BitrixClient do
  @moduledoc """
  HTTP client for Bitrix24 telephony API.
  Handles call registration and completion with retry logic.
  """

  require Logger
  alias CallFlowEngine.Calls.Call

  @default_timeout 5_000
  @default_retries 1

  @doc """
  Registers a new call with Bitrix24.
  """
  def register_call(%Call{} = call) do
    webhook_url = get_webhook_url()
    
    if webhook_url do
      endpoint = "#{webhook_url}/telephony.externalcall.register"
      
      body = %{
        "USER_PHONE_INNER" => call.callee_number || "",
        "PHONE_NUMBER" => call.caller_number || "",
        "TYPE" => direction_to_type(call.direction),
        "CALL_START_DATE" => format_datetime(call.started_at),
        "CRM_CREATE" => 0,
        "SHOW" => 0,
        "CALL_ID" => call.call_id
      }
      
      Logger.info("Registering call #{call.call_id} with Bitrix24")
      
      case post_with_retry(endpoint, body) do
        {:ok, _response} ->
          Logger.info("Successfully registered call #{call.call_id} with Bitrix24")
          :ok
        
        {:error, reason} ->
          Logger.error("Failed to register call #{call.call_id} with Bitrix24: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.debug("Bitrix24 webhook URL not configured, skipping registration")
      :ok
    end
  end

  @doc """
  Finalizes a call with Bitrix24.
  """
  def finish_call(%Call{} = call) do
    webhook_url = get_webhook_url()
    
    if webhook_url do
      endpoint = "#{webhook_url}/telephony.externalcall.finish"
      
      duration = calculate_duration(call)
      status_code = status_to_code(call.status)
      
      body = %{
        "CALL_ID" => call.call_id,
        "DURATION" => duration,
        "STATUS_CODE" => status_code,
        "RECORD_URL" => nil
      }
      
      Logger.info("Finishing call #{call.call_id} with Bitrix24")
      
      case post_with_retry(endpoint, body) do
        {:ok, _response} ->
          Logger.info("Successfully finished call #{call.call_id} with Bitrix24")
          :ok
        
        {:error, reason} ->
          Logger.error("Failed to finish call #{call.call_id} with Bitrix24: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.debug("Bitrix24 webhook URL not configured, skipping finish")
      :ok
    end
  end

  # Private Functions

  defp get_webhook_url do
    Application.get_env(:call_flow_engine, :bitrix_webhook_url)
  end

  defp post_with_retry(url, body, retries \\ @default_retries) do
    headers = [{"Content-Type", "application/json"}]
    
    case HTTPoison.post(url, Jason.encode!(body), headers, timeout: @default_timeout, recv_timeout: @default_timeout) do
      {:ok, %HTTPoison.Response{status_code: code, body: response_body}} when code in 200..299 ->
        Logger.debug("Bitrix24 responded with #{code}: #{response_body}")
        {:ok, response_body}
      
      {:ok, %HTTPoison.Response{status_code: code, body: response_body}} when code >= 500 and retries > 0 ->
        Logger.warning("Bitrix24 returned #{code}, retrying... (#{retries} retries left)")
        Logger.debug("Response body: #{response_body}")
        :timer.sleep(1_000)
        post_with_retry(url, body, retries - 1)
      
      {:ok, %HTTPoison.Response{status_code: code, body: response_body}} ->
        Logger.error("Bitrix24 returned #{code}: #{response_body}")
        {:error, {:http_error, code, response_body}}
      
      {:error, %HTTPoison.Error{reason: reason}} when retries > 0 ->
        Logger.warning("HTTP request failed: #{inspect(reason)}, retrying... (#{retries} retries left)")
        :timer.sleep(1_000)
        post_with_retry(url, body, retries - 1)
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed after retries: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp direction_to_type("inbound"), do: 1
  defp direction_to_type("outbound"), do: 2
  defp direction_to_type(_), do: 1

  defp format_datetime(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp format_datetime(datetime), do: DateTime.to_iso8601(datetime)

  defp calculate_duration(%Call{answered_at: nil}), do: 0
  defp calculate_duration(%Call{ended_at: nil}), do: 0
  defp calculate_duration(%Call{answered_at: answered, ended_at: ended}) do
    DateTime.diff(ended, answered)
  end

  defp status_to_code("finished"), do: 200
  defp status_to_code("answered"), do: 200
  defp status_to_code(_), do: 304
end
