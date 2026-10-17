defmodule AwradWeb.Problem do
  @moduledoc """
  RFC 9457 problem details, the only error shape the API sends
  (`contracts/api/STYLE.md` §7).

  Clients switch on `code`; `title` and `detail` are English, for logs only.
  """

  import Plug.Conn

  @type field_error :: %{field: String.t(), code: String.t(), detail: String.t()}

  @doc "Sends a problem response and halts the connection."
  @spec send_problem(Plug.Conn.t(), pos_integer(), String.t(), String.t(), String.t(), [
          field_error()
        ]) ::
          Plug.Conn.t()
  def send_problem(conn, status, code, title, detail, errors \\ []) do
    conn
    |> put_resp_content_type("application/problem+json")
    |> send_resp(status, Jason.encode_to_iodata!(body(status, code, title, detail, errors)))
    |> halt()
  end

  @doc "The problem body as a map, for renderers that encode it themselves."
  @spec body(pos_integer(), String.t(), String.t(), String.t(), [field_error()]) :: map()
  def body(status, code, title, detail, errors \\ []) do
    %{
      type: "urn:awrad:problem:#{code}",
      title: title,
      status: status,
      code: code,
      detail: detail,
      errors: errors
    }
  end
end
