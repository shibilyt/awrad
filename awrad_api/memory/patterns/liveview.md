# LiveView

## Page Pattern

LiveView pages live in `lib/awrad_api_web/live/` and use the `:app` layout:

```elixir
defmodule AwradApiWeb.HomeLive do
  use AwradApiWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>Content here</div>
    """
  end
end
```

The `use AwradApiWeb, :live_view` macro provides:
- `Phoenix.LiveView` with `layout: {AwradApiWeb.Layouts, :app}`
- HTML helpers (Phoenix.HTML, CoreComponents, JS alias, Gettext, verified routes)

## Layouts

### Root Layout (`layouts/root.html.heex`)

The outer HTML shell (`<html>`, `<head>`, `<body>`). Includes CSS/JS assets and nav bar.

### App Layout (`layouts.ex` — `app/1` function)

The inner content wrapper. Handles both:
- **Layout mode**: receives `@inner_content` (from Phoenix layout system)
- **Component mode**: receives `@inner_block` (from `<Layouts.app>` calls in templates)

```elixir
# lib/awrad_api_web/components/layouts.ex
def app(assigns) do
  # Renders flash_group + either @inner_content or render_slot(@inner_block)
end
```

## Adding a New LiveView Page

1. Create module in `lib/awrad_api_web/live/my_page_live.ex`
2. Add route in `router.ex`:
   ```elixir
   live "/my-page", MyPageLive
   ```
3. Access current user via `socket.assigns.current_scope.user` (if behind auth)

## Core Components

Defined in `lib/awrad_api_web/components/core_components.ex`:

| Component | Purpose |
|---|---|
| `.header` | Page header with optional `:subtitle` slot |
| `.button` | Submit button with variant, class, name, value support |
| `.input` | Form input with label, error messages, field binding |
| `.icon` | Hero icon by class name |
| `.flash` | Flash notification (info/error) |
| `.flash_group` | Standard flash group with client/server error handling |

## Reference Files

- `lib/awrad_api_web.ex` — macro definitions (`:live_view`, `:html`, etc.)
- `lib/awrad_api_web/components/layouts.ex` — layout definitions
- `lib/awrad_api_web/components/layouts/root.html.heex` — root HTML template
- `lib/awrad_api_web/components/core_components.ex` — shared components
- `lib/awrad_api_web/live/home_live.ex` — example LiveView page
