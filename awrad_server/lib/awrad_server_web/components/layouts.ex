defmodule AwradServerWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """
  use AwradServerWeb, :html

  attr :flash, :map, default: %{}
  attr :current_scope, :any, default: nil
  attr :page_title, :string, default: "Awrad"
  attr :show_navigation, :boolean, default: false
  attr :active_nav, :atom, default: nil
  attr :practice_policy, :map, default: nil
  attr :device_context, :map, default: nil
  attr :inner_content, :any, default: nil
  slot :inner_block

  def app(assigns) do
    ~H"""
    <div
      id={if @show_navigation, do: "awrad-app-shell", else: "awrad-auth-shell"}
      class={["awrad-app-shell", @show_navigation && "has-navigation"]}
      data-browser-clock={@show_navigation && "true"}
      data-day-reset={@practice_policy && @practice_policy.day_reset}
      data-calculation-method={@practice_policy && @practice_policy.calculation_method}
      data-madhab={@practice_policy && @practice_policy.madhab}
      data-location-latitude={@device_context && @device_context.latitude}
      data-location-longitude={@device_context && @device_context.longitude}
      data-location-name={@device_context && @device_context.location_name}
      data-location-source={@device_context && @device_context.location_source}
      phx-hook={@show_navigation && "BrowserClock"}
    >
      <%= if @show_navigation do %>
        <aside class="awrad-sidebar" aria-label={gettext("Primary navigation")}>
          <.brand_mark />
          <nav class="awrad-sidebar-nav">
            <.nav_link path={~p"/home"} label={gettext("Home")} icon="hero-home" active={@active_nav == :home} />
            <.nav_link path={~p"/goals"} label={gettext("Goals")} icon="hero-flag" active={@active_nav == :goals} />
            <.nav_link path={~p"/library"} label={gettext("Library")} icon="hero-book-open" active={@active_nav == :library} />
          </nav>
          <div class="awrad-sidebar-account">
            <span class="awrad-account-kicker">{gettext("Signed in as")}</span>
            <span class="awrad-account-email">{@current_scope.user.email}</span>
            <div class="awrad-account-actions">
              <.link href={~p"/users/settings"}>{gettext("Settings")}</.link>
              <.link href={~p"/users/log-out"} method="delete">{gettext("Log out")}</.link>
            </div>
          </div>
        </aside>
      <% end %>

      <div class="awrad-main-column">
        <header :if={!@show_navigation} class="awrad-auth-topbar">
          <.brand_mark compact={true} />
          <nav class="awrad-auth-topbar-links" aria-label={gettext("Account navigation")}>
            <%= if @current_scope && @current_scope.user do %>
              <span class="awrad-auth-topbar-email">{@current_scope.user.email}</span>
              <.link href={~p"/users/settings"}>{gettext("Settings")}</.link>
              <.link href={~p"/users/log-out"} method="delete">{gettext("Log out")}</.link>
            <% else %>
              <.link href={~p"/users/register"}>{gettext("Register")}</.link>
              <.link href={~p"/users/log-in"}>{gettext("Log in")}</.link>
            <% end %>
          </nav>
        </header>
        <header class="awrad-mobile-header" :if={@show_navigation}>
          <.brand_mark compact={true} />
          <span class="awrad-mobile-header-label">{@page_title}</span>
          <.link href={~p"/users/settings"} class="awrad-icon-link" aria-label={gettext("Account settings")}>
            <.icon name="hero-user-circle" class="size-6" />
          </.link>
        </header>

        <main id="main-content" class={["awrad-content", !@show_navigation && "awrad-auth-content"]}>
          <.flash_group flash={@flash} />
          <%= if @inner_content do %>
            {@inner_content}
          <% else %>
            {render_slot(@inner_block)}
          <% end %>
        </main>

        <nav :if={@show_navigation} class="awrad-bottom-nav" aria-label={gettext("Mobile navigation")}>
          <.nav_link path={~p"/home"} label={gettext("Home")} icon="hero-home" active={@active_nav == :home} />
          <.nav_link path={~p"/goals"} label={gettext("Goals")} icon="hero-flag" active={@active_nav == :goals} />
          <.nav_link path={~p"/library"} label={gettext("Library")} icon="hero-book-open" active={@active_nav == :library} />
        </nav>
      </div>
    </div>
    """
  end

  attr :compact, :boolean, default: false

  def brand_mark(assigns) do
    ~H"""
    <.link navigate={~p"/"} class={["awrad-brand", @compact && "awrad-brand-compact"]} aria-label="Awrad home">
      <span class="awrad-brand-symbol" aria-hidden="true">A</span>
      <span class="awrad-brand-name">Awrad</span>
    </.link>
    """
  end

  attr :path, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false

  def nav_link(assigns) do
    ~H"""
    <.link navigate={@path} class={["awrad-nav-link", @active && "is-active"]} aria-current={@active && "page"}>
      <.icon name={@icon} class="size-5" />
      <span>{@label}</span>
    </.link>
    """
  end

  embed_templates "layouts/*"
end
