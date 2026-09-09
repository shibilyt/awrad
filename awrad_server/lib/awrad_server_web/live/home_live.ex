defmodule AwradServerWeb.HomeLive do
  use AwradServerWeb, :live_view

  import AwradServerWeb.PracticeComponents

  alias AwradServer.Practice
  alias AwradServer.LocationSearch
  alias AwradServer.Accounts.AuthRateLimiter
  alias AwradServerWeb.PracticeLiveSupport

  @location_lookup_limit 20
  @location_lookup_window_seconds 60

  def mount(_params, _session, socket) do
    {:ok, socket} = PracticeLiveSupport.initialize(socket)

    {:ok,
     socket
     |> assign(:manual_location_error?, false)
     |> assign(:location_query, "")
     |> assign(:location_results, [])
     |> assign(:location_search_error?, false)
     |> load_home()}
  end

  def handle_event("browser_context", params, socket) do
    case PracticeLiveSupport.apply_browser_context(socket, params) do
      {:ok, socket} -> {:noreply, load_home(socket)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("save_manual_location", params, socket) do
    case PracticeLiveSupport.apply_manual_location(socket, params) do
      {:ok, socket} ->
        {:noreply,
         socket
         |> assign(:manual_location_error?, false)
         |> load_home()}

      :error ->
        {:noreply, assign(socket, :manual_location_error?, true)}
    end
  end

  def handle_event("search_location", %{"query" => query}, socket) do
    case location_lookup(socket, fn -> LocationSearch.search(query) end) do
      {:ok, results} ->
        {:noreply,
         socket
         |> assign(:location_query, query)
         |> assign(:location_results, results)
         |> assign(:location_search_error?, false)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:location_query, query)
         |> assign(:location_results, [])
         |> assign(:location_search_error?, true)}
    end
  end

  def handle_event("search_location", _params, socket) do
    {:noreply, assign(socket, :location_search_error?, true)}
  end

  def handle_event("select_location", %{"index" => index}, socket) do
    with {index, ""} <- Integer.parse(index),
         true <- index >= 0,
         location when is_map(location) <- Enum.at(socket.assigns.location_results, index),
         {:ok, socket} <- PracticeLiveSupport.apply_named_location(socket, location) do
      {:noreply,
       socket
       |> assign(:location_query, "")
       |> assign(:location_results, [])
       |> assign(:location_search_error?, false)
       |> load_home()}
    else
      _other -> {:noreply, assign(socket, :location_search_error?, true)}
    end
  end

  def handle_event("reverse_location", params, socket) do
    case location_lookup(socket, fn ->
           LocationSearch.reverse(Map.get(params, "latitude"), Map.get(params, "longitude"))
         end) do
      {:ok, %{display_name: display_name}} ->
        {:reply, %{location_name: display_name}, socket}

      {:error, _reason} ->
        {:reply, %{}, socket}
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
      practice_policy={@practice_policy}
      device_context={@device_context}
    >
      <div class="awrad-home-content awrad-home-canvas">
        <.page_intro
          class="awrad-home-header"
          title={date_label(@home.date)}
          subtitle={practice_day_subtitle(@practice_policy.day_reset, @practice_day_status)}
        />

        <div class="awrad-home-quick-stats" aria-label={gettext("Today at a glance")}>
          <span><strong>{@home.total_today_count}</strong> {gettext("counted today")}</span>
          <span aria-hidden="true">·</span>
          <span><strong>{@home.current_streak}</strong> {gettext("day streak")}</span>
          <span aria-hidden="true">·</span>
          <span><strong>{@home.active_goal_count}</strong> {gettext("active goals")}</span>
        </div>

        <section id="browser-location" class="awrad-device-context-card" aria-labelledby="browser-location-heading">
          <div>
            <p class="awrad-eyebrow">{gettext("This device")}</p>
            <h2 id="browser-location-heading">{gettext("Prayer context")}</h2>
            <p class="awrad-device-context-value">
              <%= if @device_context && not is_nil(@device_context.latitude) do %>
                {location_label(@device_context)}
              <% else %>
                {gettext("Location not set")}
              <% end %>
            </p>
            <p class="awrad-device-context-detail">
              {gettext("Timezone")}: {@device_context && @device_context.timezone || @browser_timezone}
              · {gettext("Day ends")}: {day_reset_label(@practice_policy.day_reset)}
            </p>
          </div>
          <button
            id="request-browser-location"
            type="button"
            class="awrad-secondary-button"
            data-browser-location-request
          >
            {gettext("Use this device's location")}
          </button>
          <span data-browser-location-status class="sr-only" role="status" aria-live="polite"></span>
          <form id="location-search" class="awrad-location-search" phx-submit="search_location">
            <label for="location-query">{gettext("Choose a city or place")}</label>
            <div class="awrad-location-search-row">
              <.input
                id="location-query"
                name="query"
                value={@location_query}
                type="search"
                placeholder={gettext("Search for a city")}
                autocomplete="off"
              />
              <button type="submit" class="awrad-secondary-button" aria-label={gettext("Search location")}>
                <.icon name="hero-magnifying-glass" class="size-4" />
                <span>{gettext("Search")}</span>
              </button>
            </div>
          </form>
          <p :if={@location_search_error?} class="awrad-location-error" role="alert">
            {gettext("We could not find that place. Try a city or region name.")}
          </p>
          <ul
            :if={@location_results != []}
            id="location-results"
            class="awrad-location-results"
            aria-label={gettext("Location results")}
          >
            <li :for={{location, index} <- Enum.with_index(@location_results)}>
              <button
                id={"location-result-#{index}"}
                type="button"
                class="awrad-location-result"
                phx-click="select_location"
                phx-value-index={index}
              >
                <span class="awrad-location-result-name">{location.name}</span>
                <span class="awrad-location-result-detail">{location.display_name}</span>
              </button>
            </li>
          </ul>
          <p class="awrad-location-attribution">
            {gettext("Location search uses OpenStreetMap data.")}
            <.link href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">
              {gettext("Learn more")}
            </.link>
          </p>
          <details class="awrad-manual-location">
            <summary>{gettext("Use precise coordinates instead")}</summary>
            <form id="manual-browser-location" phx-submit="save_manual_location">
              <div class="awrad-manual-location-fields">
                <.input
                  id="manual-latitude"
                  name="latitude"
                  value={nil}
                  label={gettext("Latitude")}
                  type="number"
                  min="-90"
                  max="90"
                  step="any"
                  required
                />
                <.input
                  id="manual-longitude"
                  name="longitude"
                  value={nil}
                  label={gettext("Longitude")}
                  type="number"
                  min="-180"
                  max="180"
                  step="any"
                  required
                />
              </div>
              <button type="submit" class="awrad-secondary-button">
                {gettext("Save coordinates")}
              </button>
            </form>
            <p :if={@manual_location_error?} class="awrad-location-error" role="alert">
              {gettext("Enter a valid latitude and longitude.")}
            </p>
          </details>
        </section>

        <section
          :if={@browser_prayer_times != []}
          id="home-prayer-times"
          class="awrad-prayer-times-card"
          aria-labelledby="home-prayer-times-heading"
        >
          <div class="awrad-prayer-times-header">
            <div class="awrad-prayer-times-title-group">
              <span class="awrad-prayer-times-icon" aria-hidden="true">
                <.icon name="hero-sun" class="size-5" />
              </span>
              <div>
                <p id="home-prayer-times-heading" class="awrad-eyebrow">{gettext("Prayer times")}</p>
                <p class="awrad-prayer-times-location">
                  {if @device_context, do: location_label(@device_context), else: gettext("This device")}
                </p>
              </div>
            </div>
            <div class="awrad-next-prayer" aria-label={gettext("Next prayer")}>
              <span>{gettext("Next prayer")}</span>
              <%= if @browser_next_prayer do %>
                <strong>{@browser_next_prayer.name} · {@browser_next_prayer.time}</strong>
                <small :if={@browser_next_prayer.countdown}>{@browser_next_prayer.countdown}</small>
              <% else %>
                <strong>{gettext("All prayers complete")}</strong>
              <% end %>
            </div>
          </div>

          <div class="awrad-prayer-times-list" aria-label={gettext("Today's prayer times")}>
            <div
              :for={prayer <- @browser_prayer_times}
              class={["awrad-prayer-time-row", prayer.is_next && "is-next", prayer.is_complete && "is-complete"]}
              data-prayer-name={prayer.name}
            >
              <div class="awrad-prayer-time-name">
                <span>{prayer.name}</span>
                <small :if={prayer.is_next}>{gettext("Next prayer")}</small>
              </div>
              <time data-prayer-time={prayer.name} datetime={prayer.at}>{prayer.time}</time>
              <span :if={prayer.is_complete} class="awrad-prayer-complete" aria-hidden="true">
                <.icon name="hero-check" class="size-4" />
              </span>
            </div>
          </div>
        </section>

        <p
          :if={@practice_policy.day_reset == "maghrib"}
          id="practice-day-status"
          class="awrad-practice-day-status"
          role="status"
          aria-live="polite"
        >
          <%= case @practice_day_status do %>
            <% :maghrib -> %>
              {gettext("This device is using Maghrib to start each practice day.")}
            <% :location_required -> %>
              {gettext("Add this device's location to use Maghrib day boundaries. Midnight is used until then.")}
            <% :calculation_unavailable -> %>
              {gettext("Prayer times are unavailable right now. Midnight is used for this device.")}
            <% _ -> %>
              {gettext("Maghrib day boundaries are enabled.")}
          <% end %>
        </p>

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
      Practice.home(socket.assigns.current_scope, socket.assigns.effective_date)
    )
  end

  defp allow_location_lookup?(socket) do
    user_id = socket.assigns.current_scope.user.id

    case AuthRateLimiter.allow?(
           "browser_location_lookup",
           user_id,
           @location_lookup_limit,
           @location_lookup_window_seconds
         ) do
      {:ok, _remaining} -> true
      {:error, _retry_after} -> false
    end
  end

  defp location_lookup(socket, lookup) do
    if allow_location_lookup?(socket), do: lookup.(), else: {:error, :rate_limited}
  end

  defp date_label(date), do: Calendar.strftime(date, "%A, %B %-d, %Y")

  defp practice_day_subtitle("maghrib", :maghrib), do: gettext("Practice day · Maghrib boundary")

  defp practice_day_subtitle("maghrib", _status),
    do: gettext("Practice day · midnight fallback")

  defp practice_day_subtitle(_day_reset, _status), do: gettext("Browser-local date")

  defp location_label(%{location_name: location_name})
       when is_binary(location_name) and location_name != "",
       do: location_name

  defp location_label(%{latitude: latitude, longitude: longitude}) do
    "#{format_coordinate(latitude)}, #{format_coordinate(longitude)}"
  end

  defp format_coordinate(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)

  defp day_reset_label("maghrib"), do: gettext("Maghrib")
  defp day_reset_label(_day_reset), do: gettext("midnight")
end
