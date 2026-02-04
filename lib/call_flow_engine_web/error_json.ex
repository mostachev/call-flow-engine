defmodule CallFlowEngineWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.
  """

  def render("404.json", _assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal Server Error"}}
  end

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
