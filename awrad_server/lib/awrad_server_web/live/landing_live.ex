defmodule AwradServerWeb.LandingLive do
  use AwradServerWeb, :live_view

  def mount(_params, _session, socket), do: {:ok, socket}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title={gettext("Welcome")}>
      <div class="awrad-landing">
        <div class="awrad-landing-mark" aria-hidden="true">A</div>
        <p class="awrad-eyebrow">{gettext("Awrad web companion")}</p>
        <h1>{gettext("Make room for remembrance.")}</h1>
        <p class="awrad-landing-copy">
          {gettext("Keep today’s practice close, wherever you open Awrad.")}
        </p>
        <div class="awrad-landing-actions">
          <%= if @current_scope && @current_scope.user do %>
            <.link navigate={~p"/home"} class="awrad-button awrad-button-primary">
              {gettext("Continue to home")}
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          <% else %>
            <.link navigate={~p"/users/log-in"} class="awrad-button awrad-button-primary">
              {gettext("Log in")}
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
            <.link navigate={~p"/users/register"} class="awrad-button awrad-button-secondary">
              {gettext("Create an account")}
            </.link>
          <% end %>
        </div>
        <div class="awrad-landing-note">
          <.icon name="hero-lock-closed" class="size-4" />
          <span>{gettext("Your practice is private and synced securely.")}</span>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
