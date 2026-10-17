defmodule AwradWeb.Router do
  use AwradWeb, :router

  # Every route lives under /api/v1 and is described in contracts/api/openapi.yaml
  # (STYLE.md §1). AwradWeb.ContractCoverageTest fails for any route missing there.

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Browser clients: Phoenix cookie session plus CSRF protection (ADR-2026-10-15).
  # protect_from_forgery checks X-CSRF-Token on state-changing methods only.
  pipeline :browser_session do
    plug :fetch_session
    plug :protect_from_forgery
  end

  scope "/api/v1/browser", AwradWeb do
    pipe_through [:api, :browser_session]

    get "/csrf_token", BrowserController, :csrf_token
  end

  # Swoosh mailbox preview, dev only (not part of the API).
  if Application.compile_env(:awrad, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
