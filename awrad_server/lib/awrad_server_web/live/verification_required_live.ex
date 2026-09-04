defmodule AwradServerWeb.VerificationRequiredLive do
  use AwradServerWeb, :live_view

  def mount(_params, _session, socket), do: {:ok, socket}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title={gettext("Verify your email")}>
      <div class="awrad-auth-card awrad-verification-card">
        <div class="awrad-auth-mark" aria-hidden="true">A</div>
        <p class="awrad-eyebrow">{gettext("One more step")}</p>
        <h1>{gettext("Verify your email")}</h1>
        <p class="awrad-auth-copy">
          {gettext("Confirm your email to open synced practice on the web.")}
        </p>
        <p class="awrad-auth-email">{@current_scope.user.email}</p>

        <.form for={%{}} action={~p"/users/resend-verification"} method="post" class="awrad-auth-form">
          <.button class="awrad-button awrad-button-primary awrad-button-full" phx-disable-with={gettext("Sending…")}>
            {gettext("Send a new verification email")}
            <.icon name="hero-paper-airplane" class="size-4" />
          </.button>
        </.form>

        <div class="awrad-auth-footer">
          <.link href={~p"/users/log-out"} method="delete">{gettext("Log out")}</.link>
          <span aria-hidden="true">·</span>
          <.link navigate={~p"/"}>{gettext("Back to Awrad")}</.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
