defmodule AwradWeb.Router do
  use AwradWeb, :router

  import AwradWeb.Plugs.BrowserSession, only: [check_csrf_token: 2]
  import AwradWeb.UserAuth, only: [fetch_current_scope_for_user: 2, require_authenticated_user: 2]

  # Every route lives under /api/v1 and is described in contracts/api/openapi.yaml
  # (STYLE.md §1). AwradWeb.ContractCoverageTest fails for any route missing there.
  #
  # Credentials (ADR-2026-10-15, STYLE.md §11): the browser pipeline reads only the
  # cookie session, the bearer plug only the Authorization header, and neither
  # accepts the other's credential.

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Idempotency-Key on POSTs (STYLE.md §10): the stored result is replayed.
  pipeline :idempotent do
    plug AwradWeb.Plugs.Idempotency, mode: :replay
  end

  # Browser clients: cookie session plus CSRF protection (ADR-2026-10-15).
  # check_csrf_token checks X-CSRF-Token on state-changing methods only, and
  # fetch_current_scope_for_user reads only the cookie, never Authorization.
  # Sobelow looks for `plug :protect_from_forgery` by name; check_csrf_token is
  # the same Plug.CSRFProtection, answering 403 csrf_token_invalid instead of raising.
  # sobelow_skip ["Config.CSRF"]
  pipeline :browser_session do
    plug :fetch_session
    plug :check_csrf_token
    plug :fetch_current_scope_for_user
  end

  # Browser sign-in is re-run on a repeated key: its result is a cookie.
  pipeline :idempotent_browser_sign_in do
    plug AwradWeb.Plugs.Idempotency, mode: :rerun
  end

  pipeline :require_browser_user do
    plug :require_authenticated_user
  end

  # Either credential (get_current_account): each branch checks only its own.
  pipeline :any_account do
    plug AwradWeb.Plugs.AccountAuth
  end

  # Public account operations: no credential.
  scope "/api/v1", AwradWeb do
    pipe_through [:api, :idempotent]

    post "/accounts", AccountController, :register
    post "/accounts/verify_email", AccountController, :verify_email
    post "/accounts/resend_verification_code", AccountController, :resend_verification_code
    post "/accounts/request_password_reset", AccountController, :request_password_reset
    post "/accounts/reset_password", AccountController, :reset_password
    post "/device_sessions", DeviceSessionController, :create
  end

  # Mobile token rotation and sign-out handle Idempotency-Key themselves.
  scope "/api/v1/device_sessions", AwradWeb do
    pipe_through :api

    post "/refresh", DeviceSessionController, :refresh
    post "/sign_out", DeviceSessionController, :sign_out
  end

  scope "/api/v1", AwradWeb do
    pipe_through [:api, :any_account]

    get "/account", AccountController, :show
  end

  # Account settings (slice 2b): either credential, CSRF-checked for cookies.
  scope "/api/v1/account", AwradWeb do
    pipe_through [:api, :any_account]

    get "/sessions", AccountSettingsController, :list_sessions
    delete "/sessions/:session_id", AccountSettingsController, :revoke_session
    # Checks Idempotency-Key itself: the account it would be stored for is deleted.
    post "/delete", AccountSettingsController, :delete

    # After AccountAuth, so stored results belong to the account.
    scope "/" do
      pipe_through :idempotent

      post "/sessions/revoke_others", AccountSettingsController, :revoke_other_sessions
      post "/change_password", AccountSettingsController, :change_password
      post "/request_email_change", AccountSettingsController, :request_email_change
      post "/confirm_email_change", AccountSettingsController, :confirm_email_change
    end
  end

  scope "/api/v1/browser", AwradWeb do
    pipe_through [:api, :browser_session]

    get "/csrf_token", BrowserController, :csrf_token

    scope "/" do
      pipe_through :idempotent_browser_sign_in
      post "/session", BrowserController, :create_session
    end

    scope "/" do
      pipe_through :require_browser_user
      delete "/session", BrowserController, :delete_session
    end
  end

  # Swoosh mailbox preview, dev only (not part of the API): every email the
  # server sends, at http://localhost:4000/dev/mailbox (COMMANDS.md).
  if Application.compile_env(:awrad, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
