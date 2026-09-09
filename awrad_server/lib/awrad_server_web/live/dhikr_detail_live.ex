defmodule AwradServerWeb.DhikrDetailLive do
  use AwradServerWeb, :live_view

  import AwradServerWeb.PracticeComponents

  alias AwradServer.Practice
  alias AwradServerWeb.PracticeLiveSupport

  def mount(%{"dhikr_id" => dhikr_id}, _session, socket) do
    {:ok, socket} = PracticeLiveSupport.initialize(socket)
    dhikr = Practice.get_dhikr(socket.assigns.current_scope, dhikr_id)

    {:ok,
     socket
     |> assign(:dhikr, dhikr)
     |> assign(
       :used_in_goals,
       used_in_goals(socket.assigns.current_scope, dhikr, socket.assigns.effective_date)
     )}
  end

  def handle_event("browser_context", params, socket) do
    case PracticeLiveSupport.apply_browser_context(socket, params) do
      {:ok, socket} ->
        {:noreply,
         assign(
           socket,
           :used_in_goals,
           used_in_goals(
             socket.assigns.current_scope,
             socket.assigns.dhikr,
             socket.assigns.effective_date
           )
         )}

      :error ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={gettext("Dhikr")}
      show_navigation={true}
      active_nav={:library}
      practice_policy={@practice_policy}
      device_context={@device_context}
    >
      <.link navigate={~p"/library"} class="awrad-back-link">
        <.icon name="hero-arrow-left" class="size-4" />
        {gettext("Back to library")}
      </.link>

      <%= if @dhikr do %>
        <article class="awrad-dhikr-detail">
          <div class="awrad-detail-heading">
            <p class="awrad-eyebrow">{@dhikr.category || gettext("Remembrance")}</p>
            <h1>{@dhikr.title}</h1>
            <p :if={@dhikr.transliteration} class="awrad-transliteration">{@dhikr.transliteration}</p>
          </div>

          <div class="awrad-arabic awrad-detail-arabic" dir="rtl" lang="ar">{@dhikr.arabic}</div>

          <div class="awrad-detail-translation" :if={@dhikr.translation}>
            <p class="awrad-eyebrow">{gettext("Translation")}</p>
            <p>{@dhikr.translation}</p>
          </div>

          <div class="awrad-detail-audio">
            <p class="awrad-eyebrow">{gettext("Listen")}</p>
            <.audio_preview audio_url={@dhikr.audio_url} />
          </div>

          <div :if={@dhikr.benefits != []} class="awrad-detail-benefits">
            <p class="awrad-eyebrow">{gettext("About this remembrance")}</p>
            <p>{Enum.join(@dhikr.benefits, " ")}</p>
          </div>

          <div :if={@used_in_goals != []} class="awrad-detail-goals">
            <p class="awrad-eyebrow">{gettext("In your goals")}</p>
            <.link :for={goal <- @used_in_goals} navigate={~p"/count/#{goal.id}"} class="awrad-related-goal">
              <span>{goal.title}</span>
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </article>
      <% else %>
        <.empty_state
          icon="hero-book-open"
          message={gettext("That remembrance is not available in your library.")}
          action_label={gettext("Back to library")}
          action_path={~p"/library"}
        />
      <% end %>
    </Layouts.app>
    """
  end

  defp used_in_goals(_scope, nil, _date), do: []

  defp used_in_goals(scope, dhikr, date) do
    Practice.list_goals(scope, date)
    |> Enum.filter(&(&1.dhikr_id == dhikr.id))
  end
end
