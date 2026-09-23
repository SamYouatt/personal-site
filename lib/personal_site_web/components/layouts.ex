defmodule PersonalSiteWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PersonalSiteWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <a href="#main" class="sr-only focus:not-sr-only focus:absolute focus:p-4">Skip to content</a>
    <svg aria-hidden="true" width="0" height="0" class="absolute" focusable="false">
      <defs>
        <filter
          :for={theme <- ["light", "dark"]}
          id={"wordmark-#{theme}"}
          x="-20%"
          y="-60%"
          width="140%"
          height="220%"
          color-interpolation-filters="sRGB"
        >
          <%!-- Invert dark ink before splitting, then invert back after recombining. --%>
          <feComponentTransfer in="SourceGraphic" result="ink">
            <feFuncR type="table" tableValues={if theme == "light", do: "1 0", else: "0 1"} />
            <feFuncG type="table" tableValues={if theme == "light", do: "1 0", else: "0 1"} />
            <feFuncB type="table" tableValues={if theme == "light", do: "1 0", else: "0 1"} />
          </feComponentTransfer>
          <feColorMatrix in="ink" values="1 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0" />
          <feOffset data-chroma-offset="1.2" />
          <feGaussianBlur data-chroma-blur="1.2" stdDeviation="0" result="red" />
          <feColorMatrix in="ink" values="0 0 0 0 0  0 1 0 0 0  0 0 0 0 0  0 0 0 1 0" result="green" />
          <feColorMatrix in="ink" values="0 0 0 0 0  0 0 0 0 0  0 0 1 0 0  0 0 0 1 0" />
          <feOffset data-chroma-offset="-0.8" />
          <feGaussianBlur data-chroma-blur="1" stdDeviation="0" result="blue" />
          <feBlend in="red" in2="green" mode="screen" result="red-green" />
          <feBlend in="red-green" in2="blue" mode="screen" />
          <feComponentTransfer>
            <feFuncR type="table" tableValues={if theme == "light", do: "1 0", else: "0 1"} />
            <feFuncG type="table" tableValues={if theme == "light", do: "1 0", else: "0 1"} />
            <feFuncB type="table" tableValues={if theme == "light", do: "1 0", else: "0 1"} />
            <feFuncA type="linear" slope="1.2" />
          </feComponentTransfer>
        </filter>
      </defs>
    </svg>
    <nav aria-label="Home" class="mb-8 flex flex-row justify-center px-4 pt-4">
      <.link href={~p"/"} id="back-to-posts" class="inline-flex">
        <span class="chromatic-wordmark inline-block self-center font-hero text-[2.5rem] leading-none tracking-wide text-zinc-800 md:text-[3.25rem] dark:text-zinc-200">
          Sam Youatt
        </span>
      </.link>
    </nav>
    <main id="main" class="flex-1">
      {render_slot(@inner_block)}
    </main>
    <footer class="pt-4 pb-8 text-center text-sm text-zinc-300 dark:text-zinc-600">
      Made by <a href="https://github.com/samyouatt" class="underline font-semibold">me</a> in York
    </footer>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
