defmodule AwradServerWeb.CountingLive do
  use AwradServerWeb, :live_view

  import AwradServerWeb.PracticeComponents

  alias AwradServer.Practice
  alias AwradServer.WebSync
  alias AwradServerWeb.PracticeLiveSupport

  def mount(%{"goal_id" => goal_id}, _session, socket) do
    {:ok, socket} = PracticeLiveSupport.initialize(socket)

    {:ok,
     socket
     |> assign(:goal_id, goal_id)
     |> assign(:selected_slot_id, nil)
     |> assign(:pending?, false)
     |> assign(:status, :ready)
     |> assign(:status_reason, nil)
     |> assign(:command_id, Ecto.UUID.generate())
     |> load_counter()}
  end

  def handle_event("browser_context", params, socket) do
    case PracticeLiveSupport.apply_browser_context(socket, params) do
      {:ok, socket} ->
        {:noreply,
         socket
         |> assign(:selected_slot_id, nil)
         |> assign(:status, :ready)
         |> assign(:status_reason, nil)
         |> assign(:command_id, Ecto.UUID.generate())
         |> load_counter()}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("select_slot", %{"slot_id" => slot_id}, socket) do
    if socket.assigns.counter &&
         Enum.any?(socket.assigns.counter.slots, &(&1.id == slot_id)) do
      {:noreply,
       socket
       |> assign(:selected_slot_id, slot_id)
       |> assign(:status, :ready)
       |> assign(:status_reason, nil)
       |> assign(:command_id, Ecto.UUID.generate())
       |> load_counter()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_slot", _params, socket), do: {:noreply, socket}

  def handle_event("increment", params, socket) do
    counter = socket.assigns.counter
    command_id = Map.get(params, "command_id") || socket.assigns.command_id
    slot_id = Map.get(params, "slot_id") || (counter && counter.selected_slot_id)

    cond do
      socket.assigns.pending? ->
        {:noreply, socket}

      is_nil(counter) ->
        {:noreply, assign_status(socket, :retry, :counting_unavailable)}

      not counter.can_count? ->
        {:noreply, assign_status(socket, :blocked, counter.block_reason || :counting_unavailable)}

      true ->
        send(self(), {:execute_increment, command_id, socket.assigns.goal_id, slot_id})

        {:noreply,
         socket
         |> assign(:pending?, true)
         |> assign(:status, :saving)
         |> assign(:status_reason, nil)
         |> assign(:counter, provisional_counter(counter))}
    end
  end

  def handle_info({:execute_increment, command_id, goal_id, slot_id}, socket) do
    result =
      WebSync.increment(socket.assigns.current_scope, socket.assigns.web_installation_id, %{
        command_id: command_id,
        goal_id: goal_id,
        slot_id: slot_id,
        local_date: socket.assigns.browser_date,
        timezone: socket.assigns.browser_timezone
      })

    socket = socket |> assign(:pending?, false) |> load_counter()

    case result do
      {:ok, %{status: status}} when status in [:accepted, :duplicate] ->
        {:noreply,
         socket
         |> assign(:status, :saved)
         |> assign(:status_reason, nil)
         |> assign(:command_id, Ecto.UUID.generate())}

      {:error, reason} ->
        {:noreply, assign_status(socket, :retry, reason)}

      _other ->
        {:noreply, assign_status(socket, :retry, :counting_unavailable)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={gettext("Count")}
      show_navigation={true}
      active_nav={:goals}
    >
      <.link navigate={~p"/goals"} class="awrad-back-link">
        <.icon name="hero-arrow-left" class="size-4" />
        {gettext("Back to goals")}
      </.link>

      <%= if @counter do %>
        <div id="counting-page" class="awrad-counting-page">
          <div class="awrad-counting-heading">
            <p class="awrad-eyebrow">{goal_type_label(@counter.goal.goal_type)}</p>
            <h1>{@counter.goal.title}</h1>
            <p :if={@counter.goal.translation} class="awrad-goal-translation">{@counter.goal.translation}</p>
            <p class="awrad-arabic awrad-counting-arabic" dir="rtl" lang="ar">{@counter.goal.arabic}</p>
          </div>

          <div class="awrad-count-panel">
            <div class="awrad-count-summary">
              <span class="awrad-eyebrow">{count_summary_label(@counter.goal.target_policy)}</span>
              <span class="awrad-count-target">
                <%= if @counter.target_count > 0 do %>
                  {gettext("Target")} {@counter.target_count}
                <% else %>
                  {gettext("Open practice")}
                <% end %>
              </span>
            </div>

            <div class={["awrad-count-circle", @pending? && "is-pending"]} aria-live="polite">
              <span class="awrad-count-number">{@counter.count}</span>
              <span class="awrad-count-caption">{gettext("counted")}</span>
            </div>

            <div class="awrad-count-progress">
              <div class="awrad-progress-track" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow={progress_percent(@counter)} aria-label={gettext("Count progress")}>
                <span style={"width: #{progress_percent(@counter)}%"}></span>
              </div>
              <span>{progress_label(@counter)}</span>
            </div>

            <button
              id="count-increment"
              type="button"
              class={["awrad-count-button", @pending? && "is-pending"]}
              phx-hook="CounterButton"
              phx-click="increment"
              phx-value-command-id={@command_id}
              phx-value-slot-id={@counter.selected_slot_id}
              data-count-state={"#{@status}-#{@counter.count}"}
              disabled={@pending? || not @counter.can_count?}
              aria-label={gettext("Add one count")}
              aria-keyshortcuts="Space Enter"
            >
              <.icon name="hero-plus" class="size-8" />
              <span>{gettext("Add one")}</span>
            </button>

            <div id="count-status" class={["awrad-count-status", "is-#{@status}"]} role="status" aria-live="polite">
              <%= case @status do %>
                <% :saving -> %>
                  <.icon name="hero-arrow-path" class="size-4 awrad-spin" />
                  {gettext("Saving your count…")}
                <% :saved -> %>
                  <.icon name="hero-check-circle" class="size-4" />
                  {gettext("Saved to your account")}
                <% :retry -> %>
                  <.icon name="hero-arrow-path" class="size-4" />
                  {retry_message(@status_reason)}
                <% :blocked -> %>
                  <.icon name="hero-lock-closed" class="size-4" />
                  {blocked_message(@status_reason)}
                <% _ -> %>
                  <.icon name="hero-cloud" class="size-4" />
                  {gettext("Ready to count")}
              <% end %>
            </div>
          </div>

          <section :if={@counter.slots != []} class="awrad-slot-section" aria-labelledby="slot-heading">
            <div class="awrad-section-heading">
              <div>
                <p class="awrad-eyebrow">{gettext("Where to count")}</p>
                <h2 id="slot-heading">{gettext("Select a slot")}</h2>
              </div>
            </div>
            <div class="awrad-slot-list">
              <button
                :for={slot <- @counter.slots}
                type="button"
                class={["awrad-slot-button", slot.id == @counter.selected_slot_id && "is-selected"]}
                phx-click="select_slot"
                phx-value-slot-id={slot.id}
                aria-pressed={slot.id == @counter.selected_slot_id}
              >
                <span>
                  <span class="awrad-slot-button-label">{slot.label}</span>
                  <span class="awrad-slot-button-kind">{slot_kind_label(slot)}</span>
                </span>
                <span class="awrad-slot-button-count">{slot.count}/{slot.target_count}</span>
              </button>
            </div>
          </section>

          <div class="awrad-counting-note">
            <.icon name="hero-device-phone-mobile" class="size-4" />
            {gettext("Saved progress is shared with your mobile apps after sync.")}
          </div>
        </div>
      <% else %>
        <.empty_state
          icon="hero-flag"
          message={gettext("This goal is not available for counting.")}
          action_label={gettext("Back to goals")}
          action_path={~p"/goals"}
        />
      <% end %>
    </Layouts.app>
    """
  end

  defp load_counter(socket) do
    counter =
      Practice.counter(
        socket.assigns.current_scope,
        socket.assigns.goal_id,
        socket.assigns.browser_date,
        socket.assigns.selected_slot_id
      )

    selected_slot_id = counter && counter.selected_slot_id

    socket
    |> assign(:counter, counter)
    |> assign(:selected_slot_id, selected_slot_id)
  end

  defp provisional_counter(counter) do
    count = counter.count + 1

    counter
    |> Map.put(:count, count)
    |> Map.put(:progress, progress(count, counter.target_count))
  end

  defp assign_status(socket, status, reason) do
    socket
    |> assign(:status, status)
    |> assign(:status_reason, reason)
    |> assign(:pending?, false)
  end

  defp goal_type_label(:daily), do: gettext("Daily practice")
  defp goal_type_label(:one_time), do: gettext("One-time goal")
  defp goal_type_label(:tracker), do: gettext("Open tracker")
  defp goal_type_label(:advanced), do: gettext("Advanced schedule")
  defp goal_type_label(_type), do: gettext("Practice")

  defp count_summary_label("cumulative_total"), do: gettext("All-time progress")
  defp count_summary_label(_policy), do: gettext("Today’s progress")

  defp slot_kind_label(%{web_countable?: true}), do: gettext("Anytime · available")
  defp slot_kind_label(%{timing_type: "prayer"}), do: gettext("Prayer-relative · view only")
  defp slot_kind_label(%{timing_type: "time_window"}), do: gettext("Time window · view only")
  defp slot_kind_label(_slot), do: gettext("View only")

  defp progress_percent(%{target_count: target, count: count}) when target > 0,
    do: min(round(count / target * 100), 100)

  defp progress_percent(_counter), do: 0

  defp progress_label(%{target_count: target, count: count}) when target > 0,
    do: "#{count}/#{target}"

  defp progress_label(%{count: count}), do: "#{count} #{gettext("counted")}"

  defp progress(_count, target) when target <= 0, do: 0.0
  defp progress(count, target), do: min(count / target, 1.0)

  defp retry_message(:count_cap_reached),
    do: gettext("The target is reached. Try again after the goal changes.")

  defp retry_message(:off_recurrence),
    do: gettext("This goal is not due on the selected browser date.")

  defp retry_message(:unsupported_slot), do: gettext("This slot is view-only on the web.")
  defp retry_message(:deleted), do: gettext("This goal is no longer available.")
  defp retry_message(_reason), do: gettext("We couldn’t save that count. Try again.")

  defp blocked_message(:paused), do: gettext("This goal is paused.")
  defp blocked_message(:completed), do: gettext("This goal is complete.")
  defp blocked_message(:future_start), do: gettext("This goal has not started yet.")
  defp blocked_message(:expired), do: gettext("This goal has ended.")
  defp blocked_message(:duration_ended), do: gettext("This goal’s duration has ended.")
  defp blocked_message(:unsupported_slot), do: gettext("This slot is view-only on the web.")
  defp blocked_message(_reason), do: gettext("Counting is unavailable for this goal.")
end
