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
      <div class="awrad-home-content awrad-home-canvas">
        <.page_intro
          class="awrad-home-header"
          title={date_label(@home.date)}
          subtitle={gettext("Browser-local date")}
        />

        <div class="awrad-home-quick-stats" aria-label={gettext("Today at a glance")}>
          <span><strong>{@home.total_today_count}</strong> {gettext("counted today")}</span>
          <span aria-hidden="true">·</span>
          <span><strong>{@home.current_streak}</strong> {gettext("day streak")}</span>
          <span aria-hidden="true">·</span>
          <span><strong>{@home.active_goal_count}</strong> {gettext("active goals")}</span>
        </div>

        <section id="home-todays-goals" class="awrad-section awrad-home-section awrad-home-goals-section" aria-labelledby="due-goals-heading">
          <div class="awrad-section-heading">
            <div>
              <h2 id="due-goals-heading">{gettext("Today's goals")}</h2>
            </div>
            <.link navigate={~p"/goals"} class="awrad-inline-link">
              {gettext("View all")}
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>

          <%= if @home.due_goals == [] do %>
            <div class="awrad-home-goal-stack awrad-home-goal-stack-empty">
              <.empty_state
                icon="hero-check-circle"
                message={gettext("Your practice is clear today.")}
                action_label={gettext("Browse your goals")}
                action_path={~p"/goals"}
              />
            </div>
          <% else %>
            <div class="awrad-home-goal-stack">
              <.home_goal_row :for={goal <- @home.due_goals} goal={goal} />
            </div>
          <% end %>
        </section>

        <section id="home-categories" class="awrad-section awrad-home-section" aria-labelledby="home-categories-heading">
          <div class="awrad-section-heading">
            <div>
              <p class="awrad-eyebrow">{gettext("Categories")}</p>
              <h2 id="home-categories-heading">{gettext("Featured dhikr collections")}</h2>
            </div>
            <.link navigate={~p"/library"} class="awrad-inline-link">
              {gettext("View all")}
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>

          <%= if @home.categories == [] do %>
            <.empty_state
              icon="hero-book-open"
              message={gettext("Your dhikr categories will appear here.")}
              action_label={gettext("Browse the library")}
              action_path={~p"/library"}
            />
          <% else %>
            <div class="awrad-category-scroller" aria-label={gettext("Dhikr categories")}>
              <.category_card :for={category <- @home.categories} category={category} />
            </div>
          <% end %>
        </section>

        <section id="home-wirds" class="awrad-section awrad-home-section" aria-labelledby="home-wirds-heading">
          <div class="awrad-section-heading">
            <div>
              <p class="awrad-eyebrow">{gettext("A daily reading practice")}</p>
              <h2 id="home-wirds-heading">{gettext("Featured Wirds")}</h2>
            </div>
            <.link navigate={~p"/library"} class="awrad-inline-link">
              {gettext("View all")}
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>

          <div class="awrad-wird-list">
            <.wird_card :for={wird <- @home.featured_wirds} wird={wird} />
          </div>
        </section>
      </div>
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
end
