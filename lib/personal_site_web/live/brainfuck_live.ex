defmodule PersonalSiteWeb.BrainfuckLive do
  use PersonalSiteWeb, :live_view

  alias Brainjuice.{Machine, Parser}

  @cell_px 48
  @crt_cols 72
  @tape_reach 14
  @output_tail 600

  # {label, frames per second, steps per frame}
  @speeds [
    {"1", 1, 1},
    {"2", 2, 1},
    {"5", 5, 1},
    {"10", 10, 1},
    {"30", 30, 1},
    {"60", 60, 1},
    {"MAX", 60, 40}
  ]
  @default_speed 3

  @external_resource Path.join(__DIR__, "brainfuck_live/rot13.b")
  @carts [
    %{
      id: "hello",
      name: "Hello World",
      tagline: "The classic",
      colour: "red",
      source: """
      ++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]
      >>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
      """,
      input: ""
    },
    %{
      id: "letter-a",
      name: "Letter A",
      tagline: "8 × 8 + 1",
      colour: "blue",
      source: "++++++++[>++++++++<-]>+.",
      input: ""
    },
    %{
      id: "reverse",
      name: "Reverse",
      tagline: "Backwards talk",
      colour: "green",
      source: ">,[>,]<[.<]",
      input: "brainjuice"
    },
    %{
      id: "rot13",
      name: "ROT13",
      tagline: "Top secret",
      colour: "yellow",
      source: File.read!(Path.join(__DIR__, "brainfuck_live/rot13.b")),
      input: "Uryyb, jbeyq!"
    },
    %{
      id: "blank",
      name: "Blank",
      tagline: "Write your own",
      colour: "white",
      source: "",
      input: ""
    }
  ]

  @commands [
    {">", "Move the tape head one cell to the right."},
    {"<", "Move the tape head one cell to the left."},
    {"+", "Add one to the current cell."},
    {"-", "Subtract one from the current cell."},
    {".", "Print the current cell as a character."},
    {",", "Read one byte of input into the current cell."},
    {"[", "If the current cell is zero, jump past the matching ]."},
    {"]", "If the current cell is not zero, jump back to the matching [."}
  ]

  @techniques [
    %{
      title: "Clear a cell",
      source: "+++++[-]",
      input: "",
      note: "Subtract until the cell reaches zero. You will write this in nearly every program."
    },
    %{
      title: "Move a value",
      source: "+++++[->+<]",
      input: "",
      note:
        "Empties cell 0 into cell 1. Each time round the loop takes 1 from cell 0 and adds 1 to cell 1."
    },
    %{
      title: "Copy a value",
      source: "+++++[->+>+<<]>>[-<<+>>]",
      input: "",
      note:
        "Moving destroys the original, so move it into two cells at once, then move the spare back home."
    },
    %{
      title: "Multiply to save keystrokes",
      source: "++++++++[>++++++++<-]>+.",
      input: "",
      note: "Eight laps of eight, plus one, makes 65: the letter A."
    },
    %{
      title: "Add two digits",
      source: ",>,[-<+>]<" <> String.duplicate("-", 48) <> ".",
      input: "34",
      note:
        "Reads 3 and 4 as characters, adds them, then subtracts 48 to print the digit 7. Sums over 9 print other characters."
    },
    %{
      title: "Echo until the input runs dry",
      source: ",[.,]",
      input: "hello",
      note: "Brainjuice reads 0 once the input is used up, and that zero ends the loop."
    },
    %{
      title: "Scan for an empty cell",
      source: "+>+>+>+<<<[>]",
      input: "",
      note: "Steps right until it lands on a zero. Handy for finding the end of a string."
    },
    %{
      title: "Do something once",
      source: "+[>+++<[-]]",
      input: "",
      note:
        "Brainfuck has no if. A loop that clears its own cell before it ends runs at most once."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    [cart | _] = @carts

    socket =
      socket
      |> assign(
        page_title: "Brainfuck",
        description: "A brainfuck debugger dressed up as an 8-bit games console.",
        carts: @carts,
        speeds: @speeds,
        speed: @default_speed,
        cell_px: @cell_px,
        editing?: false,
        manual?: false,
        commands: @commands,
        techniques: @techniques,
        cart_error: nil,
        tick: 0
      )
      |> insert_cart(cart)

    {:ok, socket}
  end

  @impl true
  def handle_event("step", _params, socket) do
    {:noreply, socket |> stop() |> advance(1)}
  end

  def handle_event("toggle_run", _params, %{assigns: %{status: :running}} = socket) do
    {:noreply, stop(socket)}
  end

  def handle_event("toggle_run", _params, %{assigns: %{status: status}} = socket)
      when status in [:ready, :paused] do
    {:noreply, start(socket)}
  end

  def handle_event("toggle_run", _params, socket), do: {:noreply, socket}

  def handle_event("pause", _params, socket), do: {:noreply, stop(socket)}

  def handle_event("reset", _params, socket) do
    {:noreply, socket |> stop() |> load(socket.assigns.cart)}
  end

  def handle_event("speed", %{"index" => index}, socket) do
    index = index |> String.to_integer() |> rem(length(@speeds))
    {:noreply, assign(socket, :speed, index)}
  end

  def handle_event("insert", %{"id" => id}, socket) do
    cart = Enum.find(@carts, &(&1.id == id))
    {:noreply, socket |> stop() |> insert_cart(cart)}
  end

  def handle_event("open_cart", _params, socket) do
    form = to_form(Map.take(stringify(socket.assigns.cart), ~w(name source input)), as: :cart)
    {:noreply, socket |> stop() |> assign(editing?: true, form: form, cart_error: nil)}
  end

  def handle_event("open_manual", _params, socket) do
    {:noreply, assign(socket, manual?: true)}
  end

  def handle_event("close_manual", _params, socket) do
    {:noreply, assign(socket, manual?: false)}
  end

  def handle_event("load_technique", %{"index" => index}, socket) do
    technique = Enum.at(@techniques, String.to_integer(index))

    cart = %{
      id: "manual",
      name: technique.title,
      tagline: "From the manual",
      colour: "white",
      source: technique.source,
      input: technique.input
    }

    {:noreply, socket |> stop() |> insert_cart(cart) |> assign(manual?: false)}
  end

  def handle_event("close_cart", _params, socket) do
    {:noreply, assign(socket, editing?: false, cart_error: nil)}
  end

  def handle_event("edit_cart", %{"cart" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: :cart), cart_error: nil)}
  end

  def handle_event("save_cart", %{"cart" => params}, socket) do
    cart = %{
      socket.assigns.cart
      | name: String.trim(params["name"] || "") |> blank_to("Untitled"),
        source: params["source"] || "",
        input: params["input"] || ""
    }

    case parse(cart.source) do
      {:ok, _program} ->
        {:noreply, socket |> insert_cart(cart) |> assign(editing?: false)}

      {:error, message} ->
        {:noreply, assign(socket, form: to_form(params, as: :cart), cart_error: message)}
    end
  end

  @impl true
  def handle_info({:tick, tick}, %{assigns: %{tick: tick, status: :running}} = socket) do
    {_label, _fps, steps} = Enum.at(@speeds, socket.assigns.speed)
    socket = advance(socket, steps)

    if socket.assigns.status == :running do
      {:noreply, schedule(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:tick, _stale}, socket), do: {:noreply, socket}

  defp insert_cart(socket, cart) do
    socket |> assign(cart: cart) |> load(cart)
  end

  defp load(socket, cart) do
    case parse(cart.source) do
      {:ok, program} ->
        machine = Machine.new(program, cart.input)

        socket
        |> assign(
          machine: machine,
          steps: 0,
          error: nil,
          status: if(Machine.halted?(machine), do: :halted, else: :ready)
        )
        |> present()

      {:error, message} ->
        socket
        |> assign(machine: nil, steps: 0, error: message, status: :error)
        |> present()
    end
  end

  # Boils the machine down to the small values the page shows, each in its own assign.
  # LiveView only sends an assign that changed, so a frame carries just what moved.
  defp present(%{assigns: %{machine: nil}} = socket) do
    assign(socket,
      cursor: nil,
      output: "",
      input: "",
      pc: nil,
      head: nil,
      cell: nil,
      cells: tape_cells(0, %{}),
      leader?: true
    )
  end

  defp present(%{assigns: %{machine: machine, cart: cart}} = socket) do
    head = machine.tape.head

    assign(socket,
      cursor: cursor(machine, cart.source),
      output: screen_text(machine.output),
      input: screen_text(machine.input),
      pc: machine.pc,
      head: head,
      cell: Brainjuice.Tape.read(machine.tape),
      cells: tape_cells(head, machine.tape.data),
      leader?: head - @tape_reach <= 0
    )
  end

  # The current op as a character index into the source, or nil once halted.
  defp cursor(machine, source) do
    if Machine.halted?(machine) do
      nil
    else
      position = elem(machine.program.positions, machine.pc)
      source |> binary_part(0, position) |> String.codepoints() |> length()
    end
  end

  defp tape_cells(head, data) do
    for index <- max(head - @tape_reach, 0)..(head + @tape_reach) do
      value = Map.get(data, index, 0)

      %{
        index: index,
        value: value,
        bits: bits(value),
        char: cell_char(value),
        head?: index == head
      }
    end
  end

  defp parse(source) do
    {:ok, Parser.parse(source)}
  rescue
    error in ArgumentError -> {:error, Exception.message(error)}
  end

  defp start(socket), do: socket |> assign(status: :running) |> schedule()

  defp stop(%{assigns: %{status: :running}} = socket),
    do: assign(socket, status: :paused, tick: socket.assigns.tick + 1)

  defp stop(socket), do: socket

  defp schedule(socket) do
    {_label, fps, _steps} = Enum.at(@speeds, socket.assigns.speed)
    tick = socket.assigns.tick + 1
    Process.send_after(self(), {:tick, tick}, div(1000, fps))
    assign(socket, tick: tick)
  end

  defp advance(%{assigns: %{status: status}} = socket, _count)
       when status in [:halted, :error],
       do: socket

  defp advance(socket, count) do
    %{machine: machine, steps: steps, status: status} = socket.assigns

    case run_steps(machine, steps, count) do
      {:ok, machine, steps} ->
        status =
          cond do
            Machine.halted?(machine) -> :halted
            status == :running -> :running
            true -> :paused
          end

        socket |> assign(machine: machine, steps: steps, status: status) |> present()

      {:error, machine, steps, message} ->
        socket
        |> assign(machine: machine, steps: steps, status: :error, error: message)
        |> present()
    end
  end

  # Brainjuice.Machine.step/1 raises on the tape's left edge and past the end of the program,
  # so the page checks halted?/1 first and turns a raise into the console's error state.
  defp run_steps(machine, steps, 0), do: {:ok, machine, steps}

  defp run_steps(machine, steps, count) do
    if Machine.halted?(machine) do
      {:ok, machine, steps}
    else
      try do
        Machine.step(machine)
      rescue
        error in ArgumentError -> {:error, machine, steps, Exception.message(error)}
      else
        next -> run_steps(next, steps + 1, count - 1)
      end
    end
  end

  defp stringify(map), do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp blank_to("", fallback), do: fallback
  defp blank_to(value, _fallback), do: value

  ## Rendering

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} bare>
      <div class="bj-table" aria-hidden="true"></div>
      <div id="brainjuice" class="bj-page">
        <div class="bj-desk">
          <div class="bj-clutter" aria-hidden="true">
            <img class="bj-notepad" src={~p"/images/desk/notepad.webp"} alt="" />
            <img class="bj-pencil" src={~p"/images/desk/pencil.webp"} alt="" />
            <img class="bj-mug" src={~p"/images/desk/mug.webp"} alt="" />
            <img class="bj-pen" src={~p"/images/desk/pen.webp"} alt="" />
            <img class="bj-rubber" src={~p"/images/desk/rubber.webp"} alt="" />
          </div>
          <section class="bj-stage" aria-label="Brainjuice console">
            <div class="bj-slot-area">
              <button
                id="inserted-cart"
                type="button"
                class={["bj-cart bj-cart-inserted", "bj-cart-#{@cart.colour}", @editing? && "is-out"]}
                phx-click="open_cart"
                aria-label={"Inspect the #{@cart.name} cartridge"}
              >
                <span class="bj-cart-grip" aria-hidden="true"></span>
                <span class="bj-cart-label">
                  <span class="bj-cart-brand">Brainjuice Game Pak</span>
                  <span class="bj-cart-name">{@cart.name}</span>
                </span>
              </button>
              <div class="bj-slot" aria-hidden="true"></div>
            </div>

            <div class="bj-console">
              <div class="bj-top">
                <.wordmark />
                <div class="bj-leds" role="status" aria-label={"Console status: #{@status}"}>
                  <.led label="PWR" colour="red" on />
                  <.led label="RUN" colour="green" on={@status == :running} />
                  <.led label="HLT" colour="amber" on={@status == :halted} />
                  <.led label="ERR" colour="red" on={@status == :error} />
                </div>
              </div>

              <div class="bj-main">
                <.crt
                  cart={@cart}
                  status={@status}
                  error={@error}
                  editing?={@editing?}
                  cursor={@cursor}
                  output={@output}
                  input={@input}
                />
                <div class="bj-readouts">
                  <.seven_seg id="readout-step" label="Step" value={@steps} digits={6} />
                  <.seven_seg id="readout-pc" label="PC" value={@pc} digits={4} />
                  <.seven_seg id="readout-head" label="Head" value={@head} digits={4} />
                  <.seven_seg id="readout-cell" label="Cell" value={@cell} digits={3} />
                </div>
              </div>

              <.tape_deck
                cells={@cells}
                head={@head || 0}
                leader?={@leader?}
                running?={@status == :running}
                cell_px={@cell_px}
                speed={Enum.at(@speeds, @speed)}
              />

              <div class="bj-controls">
                <div class="bj-pill-group">
                  <div class="bj-pill-wrap">
                    <button id="reset-button" type="button" class="bj-pill" phx-click="reset">
                      <span class="sr-only">Reset</span>
                    </button>
                    <span class="bj-print">Reset</span>
                  </div>
                  <div class="bj-pill-wrap">
                    <button id="eject-button" type="button" class="bj-pill" phx-click="open_cart">
                      <span class="sr-only">Inspect cartridge</span>
                    </button>
                    <span class="bj-print">Cart</span>
                  </div>
                </div>

                <div class="bj-pads">
                  <div class="bj-pad-wrap">
                    <div class="bj-pad-well">
                      <button
                        id="step-button"
                        type="button"
                        class="bj-pad"
                        phx-click="step"
                        disabled={@status in [:halted, :error]}
                      >
                        <span class="sr-only">Step</span>
                      </button>
                    </div>
                    <span class="bj-print bj-print-red">Step</span>
                  </div>
                  <div class="bj-pad-wrap">
                    <div class="bj-pad-well">
                      <button
                        id="run-button"
                        type="button"
                        class="bj-pad"
                        phx-click="toggle_run"
                        aria-pressed={to_string(@status == :running)}
                        disabled={@status in [:halted, :error]}
                      >
                        <span class="sr-only">Run / Pause</span>
                      </button>
                    </div>
                    <span class="bj-print bj-print-red">Run / Pause</span>
                  </div>
                </div>

                <.speed_knob speeds={@speeds} speed={@speed} />
              </div>

              <div class="bj-vents" aria-hidden="true"></div>
              <span class="bj-sticker" aria-hidden="true">
                <b>QC</b> PASSED<br />No. 0451 · 04/87
              </span>
            </div>
          </section>

          <section class="bj-library" aria-labelledby="library-heading">
            <h2 id="library-heading" class="sr-only">Cartridges</h2>
            <ul class="bj-rack">
              <li :for={cart <- @carts} class="bj-rack-slot">
                <button
                  id={"library-#{cart.id}"}
                  type="button"
                  class={["bj-spine", "bj-cart-#{cart.colour}"]}
                  phx-click="insert"
                  phx-value-id={cart.id}
                  aria-current={to_string(cart.id == @cart.id)}
                  aria-label={"Insert #{cart.name}"}
                >
                  <span class="bj-spine-label">
                    <span class="bj-spine-name">{cart.name}</span>
                    <span class="bj-spine-hint">{cart.tagline}</span>
                  </span>
                </button>
              </li>
            </ul>
          </section>

          <div class="bj-booklet-lift">
            <button
              id="manual-booklet"
              type="button"
              class="bj-booklet"
              phx-click="open_manual"
              aria-label="Open the user manual"
            >
              <span class="bj-booklet-band"><.wordmark /></span>
              <span class="bj-booklet-title">User Manual</span>
              <span class="bj-booklet-keys" aria-hidden="true">
                <i :for={{command, _} <- @commands}>{command}</i>
              </span>
            </button>
          </div>
        </div>

        <.manual :if={@manual?} commands={@commands} techniques={@techniques} />

        <div
          :if={@editing?}
          id="cart-editor"
          class="bj-modal"
          phx-window-keydown="close_cart"
          phx-key="Escape"
        >
          <div class="bj-modal-backdrop" phx-click="close_cart"></div>
          <div
            class={["bj-cart bj-cart-big", "bj-cart-#{@cart.colour}"]}
            role="dialog"
            aria-modal="true"
            aria-label="Cartridge label"
          >
            <span class="bj-cart-grip" aria-hidden="true"></span>
            <.form
              for={@form}
              id="cart-form"
              class="bj-cart-label bj-cart-sheet"
              phx-change="edit_cart"
              phx-submit="save_cart"
            >
              <div class="bj-sheet-head">
                <.input
                  field={@form[:name]}
                  type="text"
                  class="bj-field bj-field-title"
                  autocomplete="off"
                  placeholder="Untitled"
                  aria-label="Title"
                />
              </div>
              <.input
                field={@form[:source]}
                type="textarea"
                class="bj-field bj-field-source"
                spellcheck="false"
                rows="10"
                placeholder="Program"
                aria-label="Program"
              />
              <.input
                field={@form[:input]}
                type="text"
                class="bj-field bj-field-input"
                autocomplete="off"
                spellcheck="false"
                placeholder="Input"
                aria-label="Input"
              />
              <p :if={@cart_error} id="cart-error" class="bj-stamp" role="alert">
                Rejected: {@cart_error}
              </p>
              <div class="bj-sheet-actions">
                <button type="submit" id="save-cart" class="bj-chunky">Insert cartridge</button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :commands, :list, required: true
  attr :techniques, :list, required: true

  # Leader lines on the console drawing, in the figure's 160 × 146 viewBox, where the drawing
  # fills x 24–136 and y 14–126. Each label sits at {x, y, anchor}, and its line runs from
  # the label to a dot on the part.
  @leaders [
    {"Cartridge", {72, 6, "end"}, [{73, 6}, {75, 8.5}, {75, 20}]},
    {"Status lights", {113, 6, "start"}, [{112, 6}, {110, 8.5}, {110, 32}]},
    {"Screen", {22, 58, "end"}, [{23, 58}, {66, 58}]},
    {"Tape deck", {22, 90, "end"}, [{23, 90}, {57, 90}]},
    {"Readouts", {138, 56.5, "start"}, [{137, 56.5}, {118, 56.5}]},
    {"Reset and Cart", {12, 141, "start"}, [{40.6, 137}, {40.6, 109.6}]},
    {"Step and Run", {80, 141, "middle"}, [{80, 137}, {80, 111}]},
    {"Speed dial", {119, 141, "middle"}, [{119, 137}, {119, 110}]}
  ]

  defp manual(assigns) do
    assigns =
      assign(assigns,
        leaders: @leaders,
        technique_pages:
          assigns.techniques |> Enum.with_index() |> Enum.chunk_every(3) |> Enum.with_index()
      )

    technique_page_count = length(assigns.technique_pages)

    assigns =
      assign(assigns,
        contents: [
          {1, "Commands", 1},
          {2, "Your console", 2},
          {3, "Techniques", 4},
          {4, "Troubleshooting", 4 + technique_page_count}
        ]
      )

    ~H"""
    <div
      id="manual"
      class="bj-modal bj-manual-modal"
      phx-window-keydown="close_manual"
      phx-key="Escape"
    >
      <div class="bj-modal-backdrop" phx-click="close_manual"></div>
      <div
        id="manual-book"
        class="bj-book"
        role="dialog"
        aria-modal="true"
        aria-labelledby="manual-title"
        phx-hook="ManualBook"
        phx-update="ignore"
      >
        <div class="bj-book-pages">
          <section class="bj-leaf bj-leaf-cover">
            <.wordmark />
            <h2 id="manual-title" class="bj-manual-title">User Manual</h2>
            <p class="bj-manual-lede">
              Thank you for choosing Brainjuice. Please read this manual thoroughly to get the most
              from your new console, then keep it somewhere safe.
            </p>
            <nav class="bj-manual-contents" aria-label="Contents">
              <h3>Contents</h3>
              <ol>
                <li :for={{number, title, folio} <- @contents}>
                  <span>{number}</span>{title}<i aria-hidden="true"></i><span>{folio}</span>
                </li>
              </ol>
            </nav>
          </section>

          <section class="bj-leaf">
            <h3><span>1</span>Commands</h3>
            <p>
              Your console has a long paper tape of cells, all starting at zero, and a head that
              reads one cell at a time. A program is made of eight commands.
            </p>
            <table class="bj-manual-table">
              <tr :for={{command, meaning} <- @commands}>
                <th><code>{command}</code></th>
                <td>{meaning}</td>
              </tr>
            </table>
            <p>Every other character is ignored, use them for comments.</p>
          </section>

          <section class="bj-leaf">
            <h3><span>2</span>Your console</h3>
            <figure class="bj-sketch">
              <svg
                viewBox="0 0 160 146"
                role="img"
                aria-label="Line drawing of the console, front view, with its parts labelled"
              >
                <image
                  href={~p"/images/brainjuice-console-sketch.webp"}
                  x="24"
                  y="14"
                  width="112"
                  height="112"
                />
                <g :for={{label, {tx, ty, anchor}, points} <- @leaders} class="bj-leader">
                  <polyline points={Enum.map_join(points, " ", fn {x, y} -> "#{x},#{y}" end)} />
                  <circle
                    cx={points |> List.last() |> elem(0)}
                    cy={points |> List.last() |> elem(1)}
                    r="0.9"
                  />
                  <text x={tx} y={ty} text-anchor={anchor}>{label}</text>
                </g>
              </svg>
            </figure>
            <p class="bj-sketch-caption">Fig. 1. The Brainjuice console, front view.</p>
          </section>

          <section class="bj-leaf">
            <ol class="bj-manual-key">
              <li>
                <b>Cartridge.</b>
                Holds the program and its input. Click it to edit its program and input.
              </li>
              <li><b>Status lights.</b></li>
              <li>
                <b>Screen.</b>
                Displays the current program and indicates the next command. Input and output are displayed at the bottom.
              </li>
              <li>
                <b>Readouts.</b>
                STEP is the total number of commands run. PC is the index of the current operation. HEAD is the index of the current tape cell and CELL is its value.
              </li>
              <li>
                <b>Tape deck.</b> The tape acts as the memory of the system.
              </li>
              <li>
                <b>Reset and Cart.</b> Rewind the program, or eject the cartridge to read it.
              </li>
              <li><b>Step and Run.</b></li>
              <li><b>Speed dial.</b></li>
            </ol>
          </section>

          <section :for={{chunk, page} <- @technique_pages} class="bj-leaf">
            <h3 :if={page == 0}><span>3</span>Techniques</h3>
            <h3 :if={page > 0} class="bj-manual-cont">Techniques, continued</h3>
            <div :for={{technique, index} <- chunk} class="bj-manual-technique">
              <h4>{technique.title}</h4>
              <p>{technique.note}</p>
              <div class="bj-manual-code">
                <pre>{technique.source}</pre>
                <button
                  id={"load-technique-#{index}"}
                  type="button"
                  class="bj-manual-load"
                  phx-click="load_technique"
                  phx-value-index={index}
                >
                  Load
                </button>
              </div>
            </div>
          </section>

          <section class="bj-leaf bj-leaf-back">
            <h3><span>4</span>Troubleshooting</h3>
            <dl class="bj-manual-parts bj-manual-parts-stacked">
              <dt>Rejected: no matching ]</dt>
              <dd>Every [ needs a partner ]. Count them on the label.</dd>
              <dt>ERR: tape head moved left of 0</dt>
              <dd>The program walked off the start of the tape. Add a &gt; at the beginning.</dd>
              <dt>It never stops</dt>
              <dd>A loop only ends when its cell reaches zero. Check that the loop changes it.</dd>
              <dt>Nothing on the screen</dt>
              <dd>
                Only <code>.</code> prints. Make sure the cell holds a printable character first.
              </dd>
            </dl>
            <footer class="bj-manual-footer">
              <p>90-day limited warranty. Brainjuice Ltd., York.</p>
              <p>Brainfuck was created by Urban Müller in 1993.</p>
            </footer>
          </section>
          <button
            type="button"
            class="bj-corner bj-corner-prev"
            data-turn="-1"
            aria-label="Previous page"
          ></button>
          <button type="button" class="bj-corner bj-corner-next" data-turn="1" aria-label="Next page"></button>
        </div>
      </div>
    </div>
    """
  end

  # The Brainjuice badge. The subtitle's letters are spread to the name's width.
  defp wordmark(assigns) do
    ~H"""
    <span class="bj-badge">
      <span class="bj-badge-name">Brainjuice</span>
      <span class="bj-badge-sub" aria-label="Brainfuck System">
        <span :for={char <- String.graphemes("Brainfuck System")} aria-hidden="true">
          {if char == " ", do: "\u00A0", else: char}
        </span>
      </span>
      <span class="bj-stripes" aria-hidden="true"><i></i><i></i><i></i><i></i></span>
    </span>
    """
  end

  attr :label, :string, required: true
  attr :colour, :string, required: true
  attr :on, :boolean, default: false

  defp led(assigns) do
    ~H"""
    <span class="bj-led-wrap">
      <span class={["bj-led", "bj-led-#{@colour}", @on && "is-on"]} aria-hidden="true"></span>
      <span class="bj-print">{@label}</span>
    </span>
    """
  end

  attr :cart, :map, required: true
  attr :status, :atom, required: true
  attr :error, :string
  attr :editing?, :boolean, required: true
  attr :cursor, :integer, default: nil
  attr :output, :string, required: true
  attr :input, :string, required: true

  # The CRT is a strict character grid, @crt_cols columns wide. The listing is drawn once
  # per cartridge; each frame only moves the cursor (see the CrtCursor hook).
  defp crt(assigns) do
    ~H"""
    <div class="bj-crt-bezel">
      <div class={["bj-crt", @editing? && "is-off", @status == :running && "is-running"]}>
        <div class="bj-crt-glass">
          <div class="bj-crt-grid" style={"--cols: #{crt_cols()}"}>
            <%= if @editing? do %>
              <div :for={_ <- 1..5} class="bj-crt-row"></div>
              <div class="bj-crt-row">{centred("NO CARTRIDGE")}</div>
              <div :for={_ <- 1..6} class="bj-crt-row"></div>
            <% else %>
              <div id="crt-status" class="bj-crt-row">{status_line(@cart.name, @status)}</div>
              <div class="bj-crt-row bj-crt-rule" aria-hidden="true">{rule()}</div>
              <div class="bj-crt-pane">
                <div
                  id="crt-listing"
                  class="bj-crt-listing"
                  phx-hook="CrtCursor"
                  data-cursor={@cursor || -1}
                >
                  <pre
                    id={"crt-source-#{:erlang.phash2(@cart.source)}"}
                    phx-update="ignore"
                  >{screen_source(@cart.source)}</pre>
                </div>
                <div
                  id="crt-scrollbar"
                  class="bj-crt-scrollbar"
                  phx-update="ignore"
                  aria-hidden="true"
                >
                  <button type="button" tabindex="-1" data-scroll="-1">^</button>
                  <span class="bj-crt-track"><i></i></span>
                  <button type="button" tabindex="-1" data-scroll="1">v</button>
                </div>
              </div>
              <div class="bj-crt-row bj-crt-rule" aria-hidden="true">{rule()}</div>
              <div class="bj-crt-io">
                <pre :if={@error} id="crt-error" class="bj-crt-error">*** {String.upcase(@error)} ***</pre>
                <pre id="crt-output" class="bj-crt-output"><span class="bj-crt-prompt">OUT&gt;</span>{@output}<span class="bj-crt-caret" aria-hidden="true"></span></pre>
              </div>
              <pre id="crt-input" class="bj-crt-row bj-crt-input"><span class="bj-crt-prompt">IN&lt; </span>{@input}</pre>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp crt_cols, do: @crt_cols
  defp rule, do: String.duplicate("-", @crt_cols)

  # Tabs and carriage returns become single spaces, keeping every character in one grid cell.
  defp screen_source(source), do: String.replace(source, ["\t", "\r"], " ")

  # Cart name on the left, status ending on the last column.
  defp status_line(name, status) do
    status = status_text(status)
    name = name |> String.upcase() |> String.slice(0, @crt_cols - String.length(status) - 1)
    String.pad_trailing(name, @crt_cols - String.length(status)) <> status
  end

  defp centred(text),
    do: String.duplicate(" ", div(@crt_cols - String.length(text), 2)) <> text

  defp screen_text(bytes) do
    bytes
    |> tail(@output_tail)
    |> :binary.bin_to_list()
    |> Enum.map(fn
      byte when byte in 32..126 or byte == ?\n -> byte
      _ -> "·"
    end)
    |> IO.iodata_to_binary()
  end

  defp tail(bytes, max) when byte_size(bytes) <= max, do: bytes
  defp tail(bytes, max), do: binary_part(bytes, byte_size(bytes) - max, max)

  defp status_text(:ready), do: "READY"
  defp status_text(:running), do: "RUNNING"
  defp status_text(:paused), do: "PAUSED"
  defp status_text(:halted), do: "HALTED"
  defp status_text(:error), do: "ERROR"

  attr :cells, :list, required: true
  attr :head, :integer, required: true
  attr :leader?, :boolean, required: true
  attr :running?, :boolean, required: true
  attr :cell_px, :integer, required: true
  attr :speed, :any, required: true

  defp tape_deck(assigns) do
    ~H"""
    <div
      id="tape-deck"
      class={["bj-deck", @running? && "is-running"]}
      style={"--cell: #{@cell_px}px; --head: #{@head}; --slide: #{slide_ms(@speed)}ms"}
    >
      <div class="bj-deck-window">
        <div class="bj-tape" aria-label={"Tape, head at cell #{@head}"}>
          <span :if={@leader?} class="bj-tape-leader" aria-hidden="true">
            <span class="bj-tape-start">START</span>
          </span>
          <div
            :for={cell <- @cells}
            :key={cell.index}
            id={"cell-#{cell.index}"}
            class={["bj-cell", cell.head? && "is-head"]}
            style={"--i: #{cell.index}"}
            title={"Cell #{cell.index}: #{cell.value}"}
          >
            <span class="bj-cell-value">{cell.value}</span>
            <span class="bj-cell-holes" aria-hidden="true">
              <i
                :for={{bit, row} <- Enum.with_index(cell.bits)}
                class={[bit && "is-punched", row == 4 && "is-after-feed"]}
              ></i>
            </span>
            <span class="bj-cell-char">{cell.char}</span>
            <span class="bj-cell-index">{cell.index}</span>
          </div>
        </div>
        <div class="bj-head" aria-hidden="true">
          <span class="bj-head-label">R/W</span>
        </div>
        <span class="bj-spool bj-spool-left" aria-hidden="true"><i></i></span>
        <span class="bj-spool bj-spool-right" aria-hidden="true"><i></i></span>
      </div>
    </div>
    """
  end

  # The tape settles before the next frame, so the head lines up with the cell being read.
  defp slide_ms({_label, fps, _steps}), do: min(div(700, fps), 220)

  defp bits(value),
    do: for(shift <- 7..0//-1, do: Bitwise.band(Bitwise.bsr(value, shift), 1) == 1)

  defp cell_char(value) when value in 33..126, do: <<value>>
  defp cell_char(32), do: "␠"
  defp cell_char(10), do: "↵"
  defp cell_char(_), do: ""

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :digits, :integer, required: true

  defp seven_seg(assigns) do
    ~H"""
    <div class="bj-seg" id={@id}>
      <span class="bj-print bj-print-light">{@label}</span>
      <span class="bj-seg-window" role="img" aria-label={"#{@label} #{@value || "blank"}"}>
        <svg
          :for={{char, position} <- Enum.with_index(seg_chars(@value, @digits))}
          :key={position}
          class={"bj-seg-digit d-#{<<char>>}"}
          viewBox="0 0 12 20"
          aria-hidden="true"
        >
          <g transform="skewX(-6) translate(1.4 0)">
            <polygon :for={{segment, points} <- seg_shapes()} points={points} class={"s-#{segment}"} />
          </g>
        </svg>
      </span>
    </div>
    """
  end

  defp seg_chars(nil, digits), do: List.duplicate(?-, digits)

  defp seg_chars(value, digits) do
    value
    |> rem(Integer.pow(10, digits))
    |> Integer.to_string()
    |> String.pad_leading(digits, "0")
    |> String.to_charlist()
  end

  @seg_shapes (
                horizontal = fn y ->
                  "2.2,#{y} 3,#{y - 0.8} 9,#{y - 0.8} 9.8,#{y} 9,#{y + 0.8} 3,#{y + 0.8}"
                end

                vertical = fn x, y1, y2 ->
                  "#{x},#{y1 + 0.3} #{x + 0.8},#{y1 + 1.1} #{x + 0.8},#{y2 - 1.1} " <>
                    "#{x},#{y2 - 0.3} #{x - 0.8},#{y2 - 1.1} #{x - 0.8},#{y1 + 1.1}"
                end

                [
                  a: horizontal.(1.5),
                  b: vertical.(10.5, 1.5, 10),
                  c: vertical.(10.5, 10, 18.5),
                  d: horizontal.(18.5),
                  e: vertical.(1.5, 10, 18.5),
                  f: vertical.(1.5, 1.5, 10),
                  g: horizontal.(10)
                ]
              )

  defp seg_shapes, do: @seg_shapes

  attr :speeds, :list, required: true
  attr :speed, :integer, required: true

  defp speed_knob(assigns) do
    count = length(assigns.speeds)
    angle = fn index -> -135 + index * div(270, count - 1) end

    assigns =
      assign(assigns,
        ticks:
          Enum.with_index(assigns.speeds, fn {label, _, _}, index ->
            {label, index, angle.(index)}
          end),
        angle: angle.(assigns.speed),
        next: rem(assigns.speed + 1, count)
      )

    ~H"""
    <div class="bj-knob-wrap">
      <div class="bj-knob-dial" style={"--angle: #{@angle}deg"}>
        <button
          :for={{label, index, angle} <- @ticks}
          type="button"
          class={["bj-knob-tick", index == @speed && "is-active"]}
          style={"--angle: #{angle}deg"}
          phx-click="speed"
          phx-value-index={index}
          aria-label={"#{label} frames per second"}
        >
          <span>{label}</span>
        </button>
        <button
          id="speed-knob"
          type="button"
          class="bj-knob"
          phx-click="speed"
          phx-value-index={@next}
          aria-label="Next speed"
        >
          <span class="bj-knob-cap" aria-hidden="true"><span class="bj-knob-pointer"></span></span>
        </button>
      </div>
      <span class="bj-print">Speed</span>
    </div>
    """
  end
end
