defmodule PersonalSiteWeb.BrainfuckLive do
  use PersonalSiteWeb, :live_view

  alias Brainjuice.{Machine, Parser}

  @crt_cols 72
  @tape_reach 14
  @output_tail 600

  @max_cells Application.compile_env(:personal_site, [__MODULE__, :max_cells], 30_000)
  @max_output Application.compile_env(:personal_site, [__MODULE__, :max_output], 65_536)

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
        preload_fonts: [
          ~p"/fonts/russo-one/RussoOne-Regular.woff2",
          ~p"/fonts/jost/Jost-Variable.woff2",
          ~p"/fonts/michroma/Michroma-Regular.woff2",
          ~p"/fonts/bungee/Bungee-Regular.woff2",
          ~p"/fonts/vt323/VT323-Regular.woff2",
          ~p"/fonts/tinos/Tinos-Regular.woff2",
          ~p"/fonts/courier-prime/CourierPrime-Regular.woff2",
          ~p"/fonts/courier-prime/CourierPrime-Bold.woff2"
        ],
        carts: @carts,
        speeds: @speeds,
        speed: @default_speed,
        overlay: nil,
        commands: @commands,
        techniques: @techniques,
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
    {:noreply, socket |> stop() |> load(socket.assigns.machine.program)}
  end

  def handle_event("set_speed", %{"index" => index}, socket) do
    {:noreply, assign(socket, :speed, String.to_integer(index))}
  end

  def handle_event("insert_cart", %{"id" => id}, socket) do
    cart = Enum.find(@carts, &(&1.id == id))
    {:noreply, socket |> stop() |> insert_cart(cart)}
  end

  def handle_event("open_editor", _params, %{assigns: %{cart: cart}} = socket) do
    form =
      to_form(%{"name" => cart.name, "source" => cart.source, "input" => cart.input}, as: :cart)

    {:noreply, socket |> stop() |> assign(overlay: {:editor, form, nil})}
  end

  def handle_event("open_manual", _params, socket) do
    {:noreply, assign(socket, overlay: :manual)}
  end

  def handle_event("close_overlay", _params, socket) do
    {:noreply, assign(socket, overlay: nil)}
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

    {:noreply, socket |> stop() |> insert_cart(cart) |> assign(overlay: nil)}
  end

  def handle_event(
        "save_cart",
        %{"cart" => %{"name" => name, "source" => source, "input" => input} = params},
        socket
      ) do
    name =
      case String.trim(name) do
        "" -> "Untitled"
        name -> name
      end

    cart = %{socket.assigns.cart | name: name, source: source, input: input}

    case parse(source) do
      {:ok, program} ->
        {:noreply, socket |> insert_cart(cart, program) |> assign(overlay: nil)}

      {:error, message} ->
        {:noreply, assign(socket, overlay: {:editor, to_form(params, as: :cart), message})}
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

  defp insert_cart(socket, cart), do: insert_cart(socket, cart, Parser.parse(cart.source))

  defp insert_cart(socket, cart, program) do
    {chars, _bytes} =
      cart.source
      |> String.codepoints()
      |> Enum.with_index()
      |> Enum.map_reduce(0, fn {char, index}, byte -> {{byte, index}, byte + byte_size(char)} end)

    char_at = Map.new(chars)
    cursors = program.positions |> Tuple.to_list() |> Enum.map(&char_at[&1]) |> List.to_tuple()

    socket |> assign(cart: cart, cursors: cursors) |> load(program)
  end

  defp load(socket, program) do
    machine = Machine.new(program, socket.assigns.cart.input)

    socket
    |> assign(
      machine: machine,
      steps: 0,
      status: if(Machine.halted?(machine), do: :halted, else: :ready)
    )
    |> present()
  end

  defp present(%{assigns: %{machine: machine, cursors: cursors}} = socket) do
    head = machine.tape.head

    assign(socket,
      cursor: if(Machine.halted?(machine), do: nil, else: elem(cursors, machine.pc)),
      output: screen_text(machine.output),
      input: screen_text(machine.input),
      pc: machine.pc,
      head: head,
      cell: Brainjuice.Tape.read(machine.tape),
      cells: tape_cells(head, machine.tape.data)
    )
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

  defp advance(%{assigns: %{status: :halted}} = socket, _count), do: socket
  defp advance(%{assigns: %{status: {:error, _}}} = socket, _count), do: socket

  defp advance(socket, count) do
    %{machine: machine, steps: steps, status: status} = socket.assigns

    {machine, steps, status} =
      case run_steps(machine, steps, count) do
        {:ok, machine, steps} ->
          status =
            cond do
              map_size(machine.tape.data) > @max_cells ->
                {:error, "tape limit: more than #{@max_cells} cells used"}

              byte_size(machine.output) > @max_output ->
                {:error, "output limit: more than #{@max_output} bytes printed"}

              Machine.halted?(machine) ->
                :halted

              status == :running ->
                :running

              true ->
                :paused
            end

          {machine, steps, status}

        {:error, machine, steps, message} ->
          {machine, steps, {:error, message}}
      end

    socket |> assign(machine: machine, steps: steps, status: status) |> present()
  end

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

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        editing?: match?({:editor, _, _}, assigns.overlay),
        finished?: assigns.status == :halted or match?({:error, _}, assigns.status)
      )

    ~H"""
    <Layouts.app flash={@flash} bare>
      <div class="bj-table" aria-hidden="true"></div>
      <div id="brainjuice" class="bj-page" phx-hook="PauseWhenHidden">
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
                phx-click="open_editor"
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
                <div
                  class="bj-leds"
                  role="status"
                  aria-label={"Console status: #{status_text(@status)}"}
                >
                  <.led label="PWR" colour="red" on />
                  <.led label="RUN" colour="green" on={@status == :running} />
                  <.led label="HLT" colour="amber" on={@status == :halted} />
                  <.led label="ERR" colour="red" on={match?({:error, _}, @status)} />
                </div>
              </div>

              <div class="bj-main">
                <.crt
                  cart={@cart}
                  status={@status}
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
                head={@head}
                running?={@status == :running}
                speed={Enum.at(@speeds, @speed)}
              />

              <div class="bj-controls">
                <div class="bj-pill-group">
                  <div class="bj-pill-wrap">
                    <button
                      id="reset-button"
                      type="button"
                      class="bj-pill"
                      phx-click="reset"
                      data-sound="pill"
                    >
                      <span class="sr-only">Reset</span>
                    </button>
                    <span class="bj-print">Reset</span>
                  </div>
                  <div class="bj-pill-wrap">
                    <button
                      id="eject-button"
                      type="button"
                      class="bj-pill"
                      phx-click="open_editor"
                      data-sound="pill"
                    >
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
                        data-sound="pad"
                        type="button"
                        class="bj-pad"
                        phx-click="step"
                        disabled={@finished?}
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
                        data-sound="pad"
                        type="button"
                        class="bj-pad"
                        phx-click="toggle_run"
                        aria-pressed={to_string(@status == :running)}
                        disabled={@finished?}
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
                  data-sound="cart"
                  type="button"
                  class={["bj-spine", "bj-cart-#{cart.colour}"]}
                  phx-click="insert_cart"
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

        <div
          id="boot-screen"
          class="bj-boot"
          phx-hook="BootScreen"
          phx-mounted={JS.ignore_attributes(["data-booted"])}
          phx-update="ignore"
          aria-hidden="true"
        >
          <span class="bj-boot-mark"><.wordmark /></span>
          <span class="bj-boot-bar"><i></i></span>
        </div>

        <%= case @overlay do %>
          <% :manual -> %>
            <.manual commands={@commands} techniques={@techniques} />
          <% {:editor, form, error} -> %>
            <.cart_editor cart={@cart} form={form} error={error} />
          <% nil -> %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :cart, :map, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :error, :string, required: true

  defp cart_editor(assigns) do
    ~H"""
    <dialog
      id="cart-editor"
      data-open-sound="cart-eject"
      data-close-sound="cart-seat"
      class="bj-modal"
      phx-hook="Modal"
      aria-label="Cartridge label"
    >
      <div class={["bj-cart bj-cart-big", "bj-cart-#{@cart.colour}"]}>
        <span class="bj-cart-grip" aria-hidden="true"></span>
        <.form
          for={@form}
          id="cart-form"
          class="bj-cart-label bj-cart-sheet"
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
          <p :if={@error} id="cart-error" class="bj-stamp" role="alert">
            Rejected: {@error}
          </p>
          <div class="bj-sheet-actions">
            <button type="submit" id="save-cart" class="bj-chunky">Insert cartridge</button>
          </div>
        </.form>
      </div>
    </dialog>
    """
  end

  attr :commands, :list, required: true
  attr :techniques, :list, required: true

  @leaders (for {label, text, points} <- [
                  {"Cartridge", {72, 6, "end"}, [{73, 6}, {75, 8.5}, {75, 20}]},
                  {"Status lights", {113, 6, "start"}, [{112, 6}, {110, 8.5}, {110, 32}]},
                  {"Screen", {22, 58, "end"}, [{23, 58}, {66, 58}]},
                  {"Tape deck", {22, 90, "end"}, [{23, 90}, {57, 90}]},
                  {"Readouts", {138, 56.5, "start"}, [{137, 56.5}, {118, 56.5}]},
                  {"Reset and Cart", {12, 141, "start"}, [{40.6, 137}, {40.6, 109.6}]},
                  {"Step and Run", {80, 141, "middle"}, [{80, 137}, {80, 111}]},
                  {"Speed dial", {119, 141, "middle"}, [{119, 137}, {119, 110}]}
                ] do
              {cx, cy} = List.last(points)
              {label, text, Enum.map_join(points, " ", fn {x, y} -> "#{x},#{y}" end), {cx, cy}}
            end)

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
    <dialog
      id="manual"
      class="bj-modal bj-manual-modal"
      data-open-sound="book-open"
      data-close-sound="book-close"
      phx-hook="Modal"
      aria-labelledby="manual-title"
    >
      <div id="manual-book" class="bj-book" phx-hook="ManualBook" phx-update="ignore">
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
                <g :for={{label, {tx, ty, anchor}, points, {cx, cy}} <- @leaders} class="bj-leader">
                  <polyline points={points} />
                  <circle cx={cx} cy={cy} r="0.9" />
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
                  data-sound="cart"
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
    </dialog>
    """
  end

  @wordmark_letters "Brainfuck System"
                    |> String.graphemes()
                    |> Enum.map(&if(&1 == " ", do: "\u00A0", else: &1))

  defp wordmark(assigns) do
    assigns = assign(assigns, letters: @wordmark_letters)

    ~H"""
    <span class="bj-badge">
      <span class="bj-badge-name">Brainjuice</span>
      <span class="bj-badge-sub" aria-label="Brainfuck System">
        <span :for={char <- @letters} aria-hidden="true">{char}</span>
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
  attr :status, :any, required: true
  attr :editing?, :boolean, required: true
  attr :cursor, :integer, required: true
  attr :output, :string, required: true
  attr :input, :string, required: true

  defp crt(assigns) do
    ~H"""
    <div class="bj-crt-bezel">
      <div class={["bj-crt", @editing? && "is-off", @status == :running && "is-running"]}>
        <div class="bj-crt-glass">
          <div class="bj-crt-grid" style={"--cols: #{crt_cols()}"}>
            <%= if @editing? do %>
              <div :for={_ <- 1..5} class="bj-crt-row"></div>
              <div class="bj-crt-row text-center">NO CARTRIDGE</div>
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
                <pre :if={match?({:error, _}, @status)} id="crt-error" class="bj-crt-error">*** {@status |> elem(1) |> String.upcase()} ***</pre>
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

  defp screen_source(source), do: String.replace(source, ["\t", "\r"], " ")

  defp status_line(name, status) do
    status = status_text(status)
    name = name |> String.upcase() |> String.slice(0, @crt_cols - String.length(status) - 1)
    String.pad_trailing(name, @crt_cols - String.length(status)) <> status
  end

  defp screen_text(bytes) do
    bytes
    |> binary_slice(-@output_tail..-1//1)
    |> :binary.bin_to_list()
    |> Enum.map(fn
      byte when byte in 32..126 or byte == ?\n -> byte
      _ -> "·"
    end)
    |> IO.iodata_to_binary()
  end

  defp status_text(:ready), do: "READY"
  defp status_text(:running), do: "RUNNING"
  defp status_text(:paused), do: "PAUSED"
  defp status_text(:halted), do: "HALTED"
  defp status_text({:error, _}), do: "ERROR"

  attr :cells, :list, required: true
  attr :head, :integer, required: true
  attr :running?, :boolean, required: true
  attr :speed, :any, required: true

  defp tape_deck(assigns) do
    {_label, fps, steps} = assigns.speed
    assigns = assign(assigns, leader?: assigns.head <= @tape_reach, steps_per_second: fps * steps)

    ~H"""
    <div
      id="tape-deck"
      class={["bj-deck", @running? && "is-running"]}
      phx-hook="TapeSound"
      data-steps-per-second={@steps_per_second}
      style={"--head: #{@head}; --slide: #{slide_ms(@speed)}ms"}
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

  defp slide_ms({_label, fps, _steps}), do: min(div(700, fps), 220)

  defp bits(value),
    do: for(shift <- 7..0//-1, do: Bitwise.band(Bitwise.bsr(value, shift), 1) == 1)

  defp cell_char(value) when value in 33..126, do: <<value>>
  defp cell_char(32), do: "␠"
  defp cell_char(10), do: "↵"
  defp cell_char(_), do: ""

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :digits, :integer, required: true

  defp seven_seg(assigns) do
    ~H"""
    <div class="bj-seg" id={@id}>
      <span class="bj-print bj-print-light">{@label}</span>
      <span class="bj-seg-window" role="img" aria-label={"#{@label} #{@value}"}>
        <svg
          :for={char <- seg_chars(@value, @digits)}
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
          id={"speed-#{index}"}
          data-sound="knob"
          class={["bj-knob-tick", index == @speed && "is-active"]}
          style={"--angle: #{angle}deg"}
          phx-click="set_speed"
          phx-value-index={index}
          aria-label={"Speed #{label}"}
        >
          <span>{label}</span>
        </button>
        <button
          id="speed-knob"
          data-sound="knob"
          type="button"
          class="bj-knob"
          phx-click="set_speed"
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
