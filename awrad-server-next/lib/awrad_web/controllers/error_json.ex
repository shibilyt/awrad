defmodule AwradWeb.ErrorJSON do
  @moduledoc """
  Renders errors Phoenix raises itself (unmatched routes, parse failures,
  crashes) as RFC 9457 problems. `AwradWeb.Plugs.ApiResponseHeaders` sets the
  `application/problem+json` content type.
  """

  alias AwradWeb.Problem

  @problems %{
    400 => {"malformed_request", "Malformed request"},
    404 => {"not_found", "Not found"},
    406 => {"not_acceptable", "Not acceptable"},
    415 => {"unsupported_media_type", "Unsupported media type"},
    500 => {"internal_error", "Internal server error"}
  }

  @spec render(String.t(), map()) :: map()
  def render(template, _assigns) do
    status = template |> String.split(".") |> hd() |> String.to_integer()

    {code, title} =
      Map.get(
        @problems,
        status,
        {"http_#{status}", Phoenix.Controller.status_message_from_template(template)}
      )

    # Never leak internals: the detail is generic, the request id correlates logs.
    Problem.body(status, code, title, title)
  end
end
