defmodule AwradWeb.FallbackController do
  @moduledoc """
  Turns what an action returns instead of a response into an RFC 9457 problem
  (`action_fallback`):

    * `{:error, detail}` with a string: `400 malformed_request` (from `AwradWeb.Params`);
    * `{:error, {:validation, errors}}`: `422 validation_failed` with field codes;
    * `{:error, {:validation_at, errors}}`: the same, with errors that already
      carry their JSON Pointer and detail;
    * `{:error, {:rate_limited, seconds}}`: `429 rate_limited` with `Retry-After`;
    * `{:error, code}` with an atom: the catalogued problem for that code.
  """

  use AwradWeb, :controller

  alias AwradWeb.Problem

  @spec call(Plug.Conn.t(), {:error, term()}) :: Plug.Conn.t()
  def call(conn, {:error, detail}) when is_binary(detail), do: Problem.malformed(conn, detail)

  def call(conn, {:error, {:validation, errors}}), do: Problem.validation_failed(conn, errors)

  def call(conn, {:error, {:validation_at, errors}}),
    do: Problem.validation_failed_at(conn, errors)

  def call(conn, {:error, {:rate_limited, retry_after}}),
    do: Problem.rate_limited(conn, retry_after)

  def call(conn, {:error, code}) when is_atom(code),
    do: Problem.send_code(conn, Atom.to_string(code))
end
