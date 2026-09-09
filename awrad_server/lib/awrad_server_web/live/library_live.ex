defmodule AwradServerWeb.LibraryLive do
  use AwradServerWeb, :live_view

  import AwradServerWeb.PracticeComponents

  alias AwradServer.Practice
  alias AwradServerWeb.PracticeLiveSupport

  def mount(_params, _session, socket) do
    {:ok, socket} = PracticeLiveSupport.initialize(socket)

    {:ok,
     socket
     |> assign(:library_query, "")
     |> assign(:library_category, "all")
     |> assign(:categories, ["all"])
     |> load_library()}
  end

  def handle_params(params, _uri, socket) do
    query = Map.get(params, "query", socket.assigns.library_query)
    category = Map.get(params, "category", socket.assigns.library_category)

    {:noreply,
     socket
     |> assign(:library_query, query)
     |> assign(:library_category, category)
     |> load_library()}
  end

  def handle_event("browser_context", params, socket) do
    case PracticeLiveSupport.apply_browser_context(socket, params) do
      {:ok, socket} -> {:noreply, load_library(socket)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("search", %{"query" => query, "category" => category}, socket) do
    {:noreply,
     socket
     |> assign(:library_query, query)
     |> assign(:library_category, category)
     |> load_library()}
  end

  def handle_event("search", _params, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={gettext("Library")}
      show_navigation={true}
      active_nav={:library}
      practice_policy={@practice_policy}
      device_context={@device_context}
    >
      <.page_intro
        eyebrow={gettext("Words to return to")}
        title={gettext("Dhikr library")}
        subtitle={gettext("Read, listen, and find the remembrance behind each goal.")}
      />

      <form id="library-search" class="awrad-library-search" phx-change="search" phx-submit="search">
        <label for="library-query" class="sr-only">{gettext("Search the dhikr library")}</label>
        <div class="awrad-search-input-wrap">
          <.icon name="hero-magnifying-glass" class="size-5" />
          <input
            id="library-query"
            name="query"
            type="search"
            value={@library_query}
            placeholder={gettext("Search Arabic, transliteration, or translation")}
            autocomplete="off"
          />
        </div>
        <label for="library-category" class="sr-only">{gettext("Filter by category")}</label>
        <select id="library-category" name="category" aria-label={gettext("Filter by category")}>
          <option :for={category <- @categories} value={category} selected={category == @library_category}>
            {category_label(category)}
          </option>
        </select>
      </form>

      <div class="awrad-results-meta">
        <span>{length(@dhikrs)} {gettext("remembrances")}</span>
        <span :if={@library_query != ""}>{gettext("Matching your search")}</span>
      </div>

      <%= if @dhikrs == [] do %>
        <.empty_state
          icon="hero-book-open"
          message={gettext("No dhikr matches that search.")}
        />
      <% else %>
        <div class="awrad-dhikr-grid">
          <.dhikr_card :for={dhikr <- @dhikrs} dhikr={dhikr} />
        </div>
      <% end %>

      <div class="awrad-readonly-note">
        <.icon name="hero-information-circle" class="size-5" />
        <p>{gettext("The library is read-only on the web. Add or edit dhikr from a mobile app.")}</p>
      </div>
    </Layouts.app>
    """
  end

  defp load_library(socket) do
    dhikrs =
      Practice.search_dhikr(socket.assigns.current_scope, %{
        query: socket.assigns.library_query,
        category: socket.assigns.library_category
      })

    categories =
      if socket.assigns.categories == ["all"] do
        ["all" | Enum.map(dhikrs, & &1.category)]
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()
      else
        socket.assigns.categories
      end

    socket
    |> assign(:dhikrs, dhikrs)
    |> assign(:categories, categories)
  end

  defp category_label("all"), do: gettext("All categories")
  defp category_label(category), do: Phoenix.Naming.humanize(category)
end
