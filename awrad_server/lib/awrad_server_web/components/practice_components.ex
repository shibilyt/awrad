defmodule AwradServerWeb.PracticeComponents do
  @moduledoc "Shared presentation components for the web companion."

  use AwradServerWeb, :html

  attr :title, :string, required: true
  attr :eyebrow, :string, default: nil
  attr :subtitle, :string, default: nil
  attr :rest, :global

  def page_intro(assigns) do
    ~H"""
    <div class="awrad-page-intro" {@rest}>
      <p :if={@eyebrow} class="awrad-eyebrow">{@eyebrow}</p>
      <h1>{@title}</h1>
      <p :if={@subtitle} class="awrad-page-subtitle">{@subtitle}</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil
  attr :tone, :atom, values: [:sage, :gold, :ink], default: :sage

  def metric_card(assigns) do
    ~H"""
    <article class={["awrad-metric-card", "awrad-metric-#{@tone}"]}>
      <p class="awrad-metric-label">{@label}</p>
      <p class="awrad-metric-value">{@value}</p>
      <p :if={@hint} class="awrad-metric-hint">{@hint}</p>
    </article>
    """
  end

  attr :goal, :map, required: true
  attr :compact, :boolean, default: false

  def goal_card(assigns) do
    ~H"""
    <article class={["awrad-goal-card", @compact && "awrad-goal-card-compact"]}>
      <div class="awrad-goal-card-topline">
        <span class="awrad-status-pill" data-status={@goal.status}>
          {status_label(@goal.status)}
        </span>
        <span :if={@goal.category} class="awrad-category-label">{@goal.category}</span>
      </div>

      <div class="awrad-goal-card-copy">
        <p class="awrad-goal-title">{@goal.title}</p>
        <p :if={@goal.translation} class="awrad-goal-translation">{@goal.translation}</p>
        <p class="awrad-arabic awrad-arabic-preview" dir="rtl" lang="ar">{@goal.arabic}</p>
      </div>

      <div class="awrad-goal-progress-row">
        <div class="awrad-progress-track" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow={progress_percent(@goal)} aria-label={gettext("Goal progress")}>
          <span style={"width: #{progress_percent(@goal)}%"}></span>
        </div>
        <span class="awrad-progress-value">{progress_label(@goal)}</span>
      </div>

      <div :if={@goal.slots != []} class="awrad-goal-slots" aria-label={gettext("Goal slots")}>
        <div :for={slot <- @goal.slots} class="awrad-goal-slot-row">
          <span class="awrad-goal-slot-name">{slot.label}</span>
          <span class="awrad-goal-slot-count">{slot.count}/{slot.target_count}</span>
          <span class={["awrad-goal-slot-support", slot.web_countable? && "is-supported"]}>
            {slot_support_label(slot)}
          </span>
        </div>
      </div>

      <div class="awrad-goal-card-footer">
        <span>{count_label(@goal)}</span>
        <.link navigate={~p"/count/#{@goal.id}"} class="awrad-inline-link">
          {if @goal.web_countable?, do: gettext("Count"), else: gettext("View")}
          <.icon name="hero-arrow-right" class="size-4" />
        </.link>
      </div>
    </article>
    """
  end

  attr :dhikr, :map, required: true

  def dhikr_card(assigns) do
    ~H"""
    <article class="awrad-dhikr-card">
      <div class="awrad-dhikr-card-heading">
        <span class="awrad-dhikr-number" aria-hidden="true">✦</span>
        <div>
          <h2>{@dhikr.title}</h2>
          <p :if={@dhikr.category} class="awrad-category-label">{@dhikr.category}</p>
        </div>
        <.link navigate={~p"/library/#{@dhikr.id}"} class="awrad-icon-link" aria-label={gettext("Open dhikr")}>
          <.icon name="hero-arrow-up-right" class="size-5" />
        </.link>
      </div>
      <p class="awrad-arabic awrad-dhikr-arabic" dir="rtl" lang="ar">{@dhikr.arabic}</p>
      <p :if={@dhikr.transliteration} class="awrad-transliteration">{@dhikr.transliteration}</p>
      <p :if={@dhikr.translation} class="awrad-dhikr-translation">{@dhikr.translation}</p>
      <.audio_preview audio_url={@dhikr.audio_url} />
    </article>
    """
  end

  attr :audio_url, :string, default: nil

  def audio_preview(%{audio_url: nil} = assigns) do
    ~H"""
    <span class="awrad-audio-unavailable">{gettext("Audio unavailable")}</span>
    """
  end

  def audio_preview(assigns) do
    ~H"""
    <audio class="awrad-audio" controls preload="none" aria-label={gettext("Play audio preview")}>
      <source src={@audio_url} />
      {gettext("Your browser does not support audio playback.")}
    </audio>
    """
  end

  attr :message, :string, required: true
  attr :action_label, :string, default: nil
  attr :action_path, :string, default: nil
  attr :icon, :string, default: "hero-sparkles"

  def empty_state(assigns) do
    ~H"""
    <div class="awrad-empty-state">
      <span class="awrad-empty-icon"><.icon name={@icon} class="size-6" /></span>
      <p>{@message}</p>
      <.link :if={@action_label && @action_path} navigate={@action_path} class="awrad-button awrad-button-secondary">
        {@action_label}
        <.icon name="hero-arrow-right" class="size-4" />
      </.link>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :selected, :boolean, default: false

  def slot_pill(assigns) do
    ~H"""
    <span class={["awrad-slot-pill", @selected && "is-selected"]}>
      <span class="awrad-slot-dot" aria-hidden="true"></span>
      <span>{@label}</span>
      <span :if={@value} class="awrad-slot-value">{@value}</span>
    </span>
    """
  end

  defp status_label(:active), do: gettext("Active")
  defp status_label(:completed), do: gettext("Completed")
  defp status_label(:paused), do: gettext("Paused")
  defp status_label(_status), do: gettext("View only")

  defp progress_percent(%{target_count: target, count: count}) when target > 0 do
    min(round(count / target * 100), 100)
  end

  defp progress_percent(_goal), do: 0

  defp progress_label(%{target_count: target, count: count}) when target > 0,
    do: "#{count}/#{target}"

  defp progress_label(%{count: count}), do: "#{count} #{gettext("counted")}"

  defp count_label(%{goal_type: :one_time, count: count}), do: "#{count} #{gettext("total")}"
  defp count_label(%{today_count: count}), do: "#{count} #{gettext("today")}"

  defp slot_support_label(%{web_countable?: true}), do: gettext("Web count")
  defp slot_support_label(%{web_block_reason: :unsupported_slot}), do: gettext("View only")
  defp slot_support_label(%{web_block_reason: :off_recurrence}), do: gettext("Not due")
  defp slot_support_label(_slot), do: gettext("Unavailable")
end
