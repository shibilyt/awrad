defmodule Awrad.Accounts.Input do
  @moduledoc """
  Checks request values the accounts operations share, collecting every field
  error at once: `{:error, {:validation, [{field, code}]}}`, where `field` is
  the request field (`:email`, `:password`, `:new_password`,
  `:current_password`, `:new_email`, `:code`, `:installation_id`,
  `:device_name`, `:platform`) and `code` the stable field code clients see.
  """

  alias Awrad.Accounts.{EmailInput, PasswordPolicy}

  @type field ::
          :email
          | :password
          | :new_password
          | :current_password
          | :new_email
          | :code
          | :installation_id
          | :device_name
          | :platform
  @type field_error :: {field(), atom()}
  @type validation_error :: {:error, {:validation, [field_error(), ...]}}

  # The EmailCode schema: six ASCII digits. The server doesn't normalise other
  # digit scripts; clients do (account-model email_code_input).
  @code ~r/\A[0-9]{6}\z/
  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  # The sign-in password is checked against the hash, not the rules; only the
  # API's bounds apply (minLength 1, maxLength 1024 code points).
  @max_sign_in_password 1024

  @doc """
  Runs `checks`, a list of `{field, result}` where `result` is `:ok`,
  `{:ok, value}` or `{:error, code}`. Returns the values by field, or every
  error.
  """
  @spec collect([{field(), :ok | {:ok, term()} | {:error, atom()}}]) ::
          {:ok, %{optional(field()) => term()}} | validation_error()
  def collect(checks) do
    errors = for {field, {:error, code}} <- checks, do: {field, code}
    values = for {field, {:ok, value}} <- checks, into: %{}, do: {field, value}

    case errors do
      [] -> {:ok, values}
      errors -> {:error, {:validation, errors}}
    end
  end

  @doc "A typed email, trimmed and shape-checked (`EmailInput`)."
  @spec email(term()) :: {:ok, String.t()} | {:error, :email_invalid}
  def email(input) do
    case EmailInput.normalize(input) do
      {:ok, email} -> {:ok, email}
      :error -> {:error, :email_invalid}
    end
  end

  @doc "A new password, checked by `PasswordPolicy`."
  @spec new_password(term()) :: {:ok, String.t()} | {:error, PasswordPolicy.error()}
  def new_password(password) do
    with :ok <- PasswordPolicy.validate(password), do: {:ok, password}
  end

  @doc "A sign-in password: only the API's length bounds."
  @spec sign_in_password(term()) ::
          {:ok, String.t()} | {:error, :password_too_short | :password_too_long}
  def sign_in_password(""), do: {:error, :password_too_short}

  def sign_in_password(password) when is_binary(password) do
    too_long? =
      byte_size(password) > @max_sign_in_password * 4 or
        length(String.to_charlist(password)) > @max_sign_in_password

    if too_long?, do: {:error, :password_too_long}, else: {:ok, password}
  end

  def sign_in_password(_password), do: {:error, :password_too_short}

  @doc "An emailed code: exactly six ASCII digits."
  @spec code(term()) :: {:ok, String.t()} | {:error, :code_invalid}
  def code(code) when is_binary(code) do
    if Regex.match?(@code, code), do: {:ok, code}, else: {:error, :code_invalid}
  end

  def code(_code), do: {:error, :code_invalid}

  @doc "A mobile installation ID: a lowercase, hyphenated UUID."
  @spec installation_id(term()) :: {:ok, String.t()} | {:error, :installation_id_invalid}
  def installation_id(id) when is_binary(id) do
    if Regex.match?(@uuid, id), do: {:ok, id}, else: {:error, :installation_id_invalid}
  end

  def installation_id(_id), do: {:error, :installation_id_invalid}

  @doc "A device name: 1 to 120 code points."
  @spec device_name(term()) :: {:ok, String.t()} | {:error, :device_name_invalid}
  def device_name(name) when is_binary(name) do
    if String.valid?(name) and name != "" and length(String.to_charlist(name)) <= 120,
      do: {:ok, name},
      else: {:error, :device_name_invalid}
  end

  def device_name(_name), do: {:error, :device_name_invalid}

  @doc "A mobile platform: `android` or `ios`."
  @spec platform(term()) :: {:ok, :android | :ios} | {:error, :platform_invalid}
  def platform("android"), do: {:ok, :android}
  def platform("ios"), do: {:ok, :ios}
  def platform(_platform), do: {:error, :platform_invalid}
end
