defmodule AwradApiWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """
  use AwradApiWeb, :html

  attr :flash, :map, default: %{}
  attr :current_scope, :any, default: nil
  attr :inner_content, :any, default: nil
  slot :inner_block

  def app(assigns) do
    ~H"""
    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl">
        <.flash_group flash={@flash} />
        <%= if @inner_content do %>
          {@inner_content}
        <% else %>
          {render_slot(@inner_block)}
        <% end %>
      </div>
    </main>
    """
  end

  embed_templates "layouts/*"
end
