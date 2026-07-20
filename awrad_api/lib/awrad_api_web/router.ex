defmodule AwradApiWeb.Router do
  use AwradApiWeb, :router

  import AwradApiWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AwradApiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug AwradApiWeb.Plugs.ApiAuth
  end

  pipeline :api_auth_verified do
    plug :accepts, ["json"]
    plug AwradApiWeb.Plugs.ApiAuth
    plug AwradApiWeb.Plugs.RequireVerifiedEmail
  end

  # LiveView web app
  scope "/", AwradApiWeb do
    pipe_through :browser

    live "/", HomeLive
    get "/auth/mobile/verify-email/:token", EmailVerificationController, :mobile
    get "/auth/verify-email/:token", EmailVerificationController, :verify
  end

  # Mobile operating systems fetch these unauthenticated JSON association files.
  scope "/.well-known", AwradApiWeb do
    pipe_through :api

    get "/apple-app-site-association", MobileAssociationController, :apple
    get "/assetlinks.json", MobileAssociationController, :android
  end

  # Mobile API - public auth endpoints
  scope "/api", AwradApiWeb.Api do
    pipe_through :api

    get "/community/stats", CommunityStatsController, :show
  end

  scope "/api/auth", AwradApiWeb.Api do
    pipe_through :api

    post "/register", AuthController, :register
    post "/login", AuthController, :login
    post "/refresh", AuthController, :refresh
    post "/verify-email", AuthController, :verify_email
    post "/verify-email/resend", AuthController, :resend_verification
    post "/forgot-password", AuthController, :forgot_password
    post "/reset-password", AuthController, :reset_password
  end

  # Mobile API - authenticated endpoints
  scope "/api", AwradApiWeb.Api do
    pipe_through :api_auth

    delete "/auth/logout", AuthController, :logout
    get "/auth/sessions", AuthController, :sessions
    delete "/auth/sessions/:id", AuthController, :revoke_session
    delete "/auth/sessions", AuthController, :revoke_all_sessions
  end

  # Progress sync is restricted to verified bearer-token identities. Ownership is
  # always derived from current_scope inside the context boundary.
  scope "/api/sync/v1/progress", AwradApiWeb.Api do
    pipe_through :api_auth_verified

    post "/commands", ProgressSyncController, :commands
    post "/actors/ack", ProgressSyncController, :acknowledge
    post "/snapshots", ProgressSyncController, :snapshot
    post "/deltas", ProgressSyncController, :delta
    get "/snapshots/:id/pages/:page", ProgressSyncController, :page
    get "/deltas/:id/pages/:page", ProgressSyncController, :page
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:awrad_api, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: AwradApiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", AwradApiWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", AwradApiWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", AwradApiWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    get "/users/reset-password", UserResetPasswordController, :new
    post "/users/reset-password", UserResetPasswordController, :create
    get "/users/reset-password/:token", UserResetPasswordController, :edit
    put "/users/reset-password", UserResetPasswordController, :update
  end
end
