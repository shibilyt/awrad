defmodule AwradServerWeb.GoalsLive do
  use AwradServerWeb, :live_view

  import AwradServerWeb.PracticeComponents

  alias AwradServer.Practice
  alias AwradServerWeb.PracticeLiveSupport

  def mount(_params, _session, socket) do
    {:ok, socket} = PracticeLiveSupport.initialize(socket)

    {:ok,
     socket
     |> assign(:goal_filter, :active)
     |> load_goals()}
  end

  def handle_event("browser_context", params, socket) do
    case PracticeLiveSupport.apply_browser_context(socket, params) do
      {:ok, socket} -> {:noreply, load_goals(socket)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("filter", %{"filter" => filter}, socket)
      when filter in ["all", "active", "completed"] do
    {:noreply, assign(socket, :goal_filter, String.to_existing_atom(filter))}
  end

  def handle_event("filter", _params, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={gettext("Goals")}
      show_navigation={true}
      active_nav={:goals}
    >
      <.page_intro
        eyebrow={gettext("Your commitments")}
        title={gettext("Goals")}
        subtitle={gettext("A read-only view of your synced practice.")}
      />

      <div class="awrad-toolbar" role="toolbar" aria-label={gettext("Goal filters")}>
        <button
          :for={filter <- [:active, :completed, :all]}
          type="button"
          class={["awrad-filter-button", @goal_filter == filter && "is-active"]}
          phx-click="filter"
          phx-value-filter={filter}
          aria-pressed={@goal_filter == filter}
        >
          {filter_label(filter)}
        </button>
        <span class="awrad-toolbar-note">
          {length(filtered_goals(@goals, @goal_filter))} {gettext("shown")}
        </span>
      </div>

      <%= if filtered_goals(@goals, @goal_filter) == [] do %>
        <.empty_state
          icon="hero-flag"
          message={empty_message(@goals, @goal_filter)}
          action_label={if @goals == [], do: gettext("Browse the library"), else: nil}
          action_path={if @goals == [], do: ~p"/library", else: nil}
        />
      <% else %>
        <div class="awrad-goal-grid awrad-goal-grid-single">
          <.goal_card :for={goal <- filtered_goals(@goals, @goal_filter)} goal={goal} />
        </div>
      <% end %>

      <div class="awrad-readonly-note">
        <.icon name="hero-information-circle" class="size-5" />
        <p>
          {gettext("Goal editing stays in the mobile apps for now. Web counting is available only for active anytime slots.")}
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp load_goals(socket) do
    assign(
      socket,
      :goals,
      Practice.list_goals(socket.assigns.current_scope, socket.assigns.browser_date)
    )
  end

  defp filtered_goals(goals, :all), do: goals
  defp filtered_goals(goals, :active), do: Enum.filter(goals, &(&1.status == :active))
  defp filtered_goals(goals, :completed), do: Enum.filter(goals, &(&1.status == :completed))

  defp filter_label(:active), do: gettext("Active")
  defp filter_label(:completed), do: gettext("Completed")
  defp filter_label(:all), do: gettext("All goals")

  defp empty_message([], _filter), do: gettext("No goals yet")
  defp empty_message(_goals, :completed), do: gettext("No completed goals")
  defp empty_message(_goals, :active), do: gettext("No active goals")
  defp empty_message(_goals, :all), do: gettext("No goals yet")
end
