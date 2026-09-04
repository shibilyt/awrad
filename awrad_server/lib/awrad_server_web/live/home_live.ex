defmodule AwradServerWeb.HomeLive do
  use AwradServerWeb, :live_view

  import AwradServerWeb.PracticeComponents

  alias AwradServer.Practice
  alias AwradServerWeb.PracticeLiveSupport

  def mount(_params, _session, socket) do
    {:ok, socket} = PracticeLiveSupport.initialize(socket)
    {:ok, load_home(socket)}
  end

  def handle_event("browser_context", params, socket) do
    case PracticeLiveSupport.apply_browser_context(socket, params) do
      {:ok, socket} -> {:noreply, load_home(socket)}
      :error -> {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={gettext("Home")}
      show_navigation={true}
      active_nav={:home}
    >
      <.page_intro
        eyebrow={gettext("Awrad web companion")}
        title={gettext("Today")}
        subtitle={date_label(@home.date)}
      />

      <div class="awrad-session-note">
        <.icon name="hero-globe-alt" class="size-4" />
        <span>
          {gettext("Web session")}
          <span aria-hidden="true"> · </span>
          {gettext("Browser-local date")}
        </span>
      </div>

      <div class="awrad-metric-grid" aria-label={gettext("Today at a glance")}>
        <.metric_card
          label={gettext("Counted today")}
          value={@home.total_today_count}
          hint={gettext("Across due goals")}
          tone={:sage}
        />
        <.metric_card
          label={gettext("Current streak")}
          value={@home.current_streak}
          hint={gettext("Consecutive days")}
          tone={:gold}
        />
        <.metric_card
          label={gettext("Active goals")}
          value={@home.active_goal_count}
          hint={gettext("Ready to practice")}
          tone={:ink}
        />
      </div>

      <section class="awrad-section" aria-labelledby="due-goals-heading">
        <div class="awrad-section-heading">
          <div>
            <p class="awrad-eyebrow">{gettext("Your practice")}</p>
            <h2 id="due-goals-heading">{gettext("Due today")}</h2>
          </div>
          <.link navigate={~p"/goals"} class="awrad-inline-link">
            {gettext("All goals")}
            <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </div>

        <%= if @home.due_goals == [] do %>
          <.empty_state
            icon="hero-check-circle"
            message={gettext("Your practice is clear today.")}
            action_label={gettext("Browse your goals")}
            action_path={~p"/goals"}
          />
        <% else %>
          <div class="awrad-goal-grid">
            <.goal_card :for={goal <- @home.due_goals} goal={goal} />
          </div>
        <% end %>
      </section>

      <section class="awrad-section awrad-contribution-card" aria-labelledby="recent-heading">
        <div class="awrad-section-heading">
          <div>
            <p class="awrad-eyebrow">{gettext("Keep the thread")}</p>
            <h2 id="recent-heading">{gettext("Recent practice")}</h2>
          </div>
          <span class="awrad-section-count">{length(@home.contribution_dates)} {gettext("days")}</span>
        </div>
        <div class="awrad-contribution-dots" aria-label={gettext("Recent contribution days")}>
          <span :for={date <- recent_dates(@home.contribution_dates)} class="awrad-contribution-dot is-filled" title={Date.to_string(date)}></span>
          <span :for={_empty <- empty_contribution_slots(@home.contribution_dates)} class="awrad-contribution-dot"></span>
        </div>
        <p class="awrad-muted-copy">
          {gettext("Canonical progress is saved as you count. Mobile changes appear after the next refresh.")}
        </p>
      </section>
    </Layouts.app>
    """
  end

  defp load_home(socket) do
    assign(
      socket,
      :home,
      Practice.home(socket.assigns.current_scope, socket.assigns.browser_date)
    )
  end

  defp date_label(date), do: Calendar.strftime(date, "%A, %B %-d, %Y")

  defp recent_dates(dates), do: Enum.take(dates, -7)

  defp empty_contribution_slots(dates),
    do: List.duplicate(nil, max(0, 7 - length(Enum.take(dates, -7))))
end
