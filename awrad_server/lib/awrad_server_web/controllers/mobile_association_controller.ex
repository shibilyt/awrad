defmodule AwradServerWeb.MobileAssociationController do
  use AwradServerWeb, :controller

  @verification_paths ["/auth/mobile/verify-email/*", "/auth/verify-email/*"]

  def apple(conn, _params) do
    config = Application.fetch_env!(:awrad_server, :mobile_app_links)

    association = %{
      applinks: %{
        apps: [],
        details: [%{appID: Keyword.fetch!(config, :ios_app_id), paths: @verification_paths}]
      }
    }

    association_json(conn, association)
  end

  def android(conn, _params) do
    config = Application.fetch_env!(:awrad_server, :mobile_app_links)

    association = [
      %{
        relation: ["delegate_permission/common.handle_all_urls"],
        target: %{
          namespace: "android_app",
          package_name: Keyword.fetch!(config, :android_package),
          sha256_cert_fingerprints: Keyword.fetch!(config, :android_sha256_cert_fingerprints)
        }
      }
    ]

    association_json(conn, association)
  end

  defp association_json(conn, body) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> put_resp_content_type("application/json")
    |> send_resp(:ok, Jason.encode!(body))
  end
end
