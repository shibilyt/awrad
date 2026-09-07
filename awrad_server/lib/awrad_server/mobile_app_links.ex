defmodule AwradServer.MobileAppLinks do
  @moduledoc false

  @ios_team_id_pattern ~r/^[A-Z0-9]{10}$/
  @fingerprint_pattern ~r/^(?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$/

  @spec ios_app_id(term()) :: String.t() | nil
  def ios_app_id(value) when is_binary(value) do
    team_id = String.trim(value)

    if Regex.match?(@ios_team_id_pattern, team_id) do
      "#{team_id}.app.awrad.awrad"
    end
  end

  def ios_app_id(_value), do: nil

  @spec android_sha256_cert_fingerprints(term()) :: [String.t()]
  def android_sha256_cert_fingerprints(value) when is_binary(value) do
    fingerprints =
      value
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)

    if Enum.all?(fingerprints, &Regex.match?(@fingerprint_pattern, &1)) do
      Enum.map(fingerprints, &String.upcase/1)
    else
      []
    end
  end

  def android_sha256_cert_fingerprints(_value), do: []
end
