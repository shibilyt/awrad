defmodule Awrad.Accounts.EmailInput do
  @moduledoc """
  The email rule every client and the server share
  (`contracts/account-model/v1/fixtures/email_input.json`):

    1. trim the explicit whitespace set (Unicode White_Space plus U+200B and
       U+FEFF) from both ends;
    2. check the shape: one `@`, a non-empty local part, a domain of at least two
       non-empty dot-separated labels, no whitespace inside, at most 160 code
       points.

  Case is kept as typed; the database compares emails case-insensitively
  (`citext`).
  """

  @max_code_points 160

  # Unicode White_Space, plus zero-width space and BOM (account-model README).
  @whitespace [
                0x09..0x0D,
                [0x20, 0x85, 0xA0, 0x1680],
                0x2000..0x200A,
                [0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0x200B, 0xFEFF]
              ]
              |> Enum.flat_map(&Enum.to_list/1)
              |> MapSet.new()

  @doc """
  Trims and checks a typed email. Returns `{:ok, email}` or `:error`.

      iex> Awrad.Accounts.EmailInput.normalize(" Amina@Example.com ")
      {:ok, "Amina@Example.com"}

      iex> Awrad.Accounts.EmailInput.normalize("amina@localhost")
      :error
  """
  @spec normalize(term()) :: {:ok, String.t()} | :error
  def normalize(input) when is_binary(input) do
    with true <- String.valid?(input),
         email = trim(input),
         true <- valid_shape?(email) do
      {:ok, email}
    else
      false -> :error
    end
  end

  def normalize(_input), do: :error

  @doc "Whether `codepoint` is in the shared whitespace set."
  @spec whitespace?(integer()) :: boolean()
  def whitespace?(codepoint), do: MapSet.member?(@whitespace, codepoint)

  defp trim(string) do
    string
    |> String.to_charlist()
    |> Enum.drop_while(&whitespace?/1)
    |> Enum.reverse()
    |> Enum.drop_while(&whitespace?/1)
    |> Enum.reverse()
    |> List.to_string()
  end

  defp valid_shape?(email) do
    codepoints = String.to_charlist(email)

    length(codepoints) <= @max_code_points and not Enum.any?(codepoints, &whitespace?/1) and
      valid_parts?(String.split(email, "@"))
  end

  defp valid_parts?([local, domain]) when local != "" do
    labels = String.split(domain, ".")
    length(labels) >= 2 and Enum.all?(labels, &(&1 != ""))
  end

  defp valid_parts?(_parts), do: false
end
