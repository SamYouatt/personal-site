defmodule PersonalSiteWeb.PageControllerTest do
  use PersonalSiteWeb.ConnCase, async: true

  test "index links all five posts in newest-first order, including the WIP", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#posts h2 a") |> LazyHTML.attribute("href") == [
             "/so-calendar-tui/",
             "/so-calendar-1/",
             "/particles/",
             "/site-design/",
             "/a-classy-refactoring/"
           ]

    assert document |> LazyHTML.query("#post-so-calendar-tui h2") |> LazyHTML.text() =~ "[WIP]"
  end

  test "pages link to the served favicon", %{conn: conn} do
    for path <- ["/", "/particles/"] do
      document = conn |> get(path) |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("link[rel=icon]") |> LazyHTML.attribute("href") ==
               ["/favicon.ico"]
    end

    icon = get(conn, "/favicon.ico")
    assert response(icon, 200) == File.read!("priv/static/favicon.ico")
    assert binary_part(icon.resp_body, 0, 4) == <<0, 0, 1, 0>>
  end
end
