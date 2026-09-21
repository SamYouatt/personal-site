defmodule PersonalSiteWeb.ErrorHTMLTest do
  use PersonalSiteWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    document =
      PersonalSiteWeb.ErrorHTML
      |> render_to_string("404", "html", [])
      |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query("h1#not-found-title.font-hero > span")
           |> Enum.map(&LazyHTML.text/1) == ["404", "Not 'ere"]

    assert document |> LazyHTML.query("a") |> Enum.count() == 0
    assert document |> LazyHTML.query("link[rel=stylesheet]") |> Enum.count() == 1

    assert document |> LazyHTML.query("link[rel=icon]") |> LazyHTML.attribute("href") ==
             ["/favicon.ico"]
  end

  test "renders 500.html" do
    assert render_to_string(PersonalSiteWeb.ErrorHTML, "500", "html", []) ==
             "Internal Server Error"
  end
end
