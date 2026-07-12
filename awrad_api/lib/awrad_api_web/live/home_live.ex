defmodule AwradApiWeb.HomeLive do
  use AwradApiWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="text-center">
      <h1 class="text-3xl font-bold text-emerald-700">Awrad</h1>
      <p class="mt-4 text-lg text-gray-600">Community for Dhaakirs</p>
    </div>
    """
  end
end
