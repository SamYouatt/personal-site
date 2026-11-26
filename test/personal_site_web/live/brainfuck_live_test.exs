defmodule PersonalSiteWeb.BrainfuckLiveTest do
  use PersonalSiteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "running a cartridge at full speed prints its output and halts", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/brainfuck")

    view |> element("#library-hello") |> render_click()
    view |> element(~s(button[aria-label="MAX frames per second"])) |> render_click()
    view |> element("#run-button") |> render_click()

    assert eventually(fn -> has_element?(view, "#crt-status", "HALTED") end)
    assert has_element?(view, "#crt-output", "Hello World!")
    assert has_element?(view, "#run-button[disabled]")
  end

  test "stepping reads the cartridge input one byte at a time", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/brainfuck")
    view |> element("#library-reverse") |> render_click()

    # >,[>,]<[.<] reads the first byte on its second op.
    view |> element("#step-button") |> render_click()
    assert has_element?(view, "#crt-input", "brainjuice")
    view |> element("#step-button") |> render_click()
    assert has_element?(view, "#crt-input", "rainjuice")

    step_until_halted(view)
    assert has_element?(view, "#crt-output", "eciujniarb")
  end

  test "a cartridge with unbalanced brackets is rejected and stays in the editor", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/brainfuck")

    view |> element("#inserted-cart") |> render_click()
    view |> form("#cart-form", cart: %{source: "+[>+<-]]"}) |> render_submit()

    assert has_element?(view, "#cart-error", "no matching [ for ]")
    assert has_element?(view, "#cart-editor")
  end

  test "moving the head left of cell 0 stops the console with an error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/brainfuck")

    view |> element("#inserted-cart") |> render_click()
    view |> form("#cart-form", cart: %{name: "Fall off", source: "+<+"}) |> render_submit()
    refute has_element?(view, "#cart-editor")

    view |> element("#step-button") |> render_click()
    view |> element("#step-button") |> render_click()

    assert has_element?(view, "#crt-error", "TAPE HEAD MOVED LEFT OF 0")
    assert has_element?(view, "#step-button[disabled]")
    assert has_element?(view, ~s(#readout-cell [aria-label="Cell 1"]))
  end

  test "loading a technique from the manual inserts it as a cartridge", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/brainfuck")

    view |> element("#manual-booklet") |> render_click()
    view |> element("#load-technique-3") |> render_click()

    refute has_element?(view, "#manual")
    assert has_element?(view, "#inserted-cart", "Multiply to save keystrokes")
    step_until_halted(view)
    assert has_element?(view, "#crt-output", "A")
  end

  defp step_until_halted(view, limit \\ 500) do
    Enum.reduce_while(1..limit, nil, fn _, _ ->
      if has_element?(view, "#step-button[disabled]") do
        {:halt, :ok}
      else
        view |> element("#step-button") |> render_click()
        {:cont, nil}
      end
    end)
  end

  defp eventually(check, attempts \\ 60) do
    cond do
      check.() -> true
      attempts == 0 -> false
      true -> Process.sleep(50) && eventually(check, attempts - 1)
    end
  end
end
