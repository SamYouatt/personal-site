defmodule PersonalSiteWeb.BlogControllerTest do
  use PersonalSiteWeb.ConnCase, async: true

  @posts [
    {"a-classy-refactoring", "A Classy Refactoring", "2021-11-29"},
    {"site-design", "Site Design", "2021-12-05"},
    {"particles", "Particles", "2022-06-15"},
    {"so-calendar-1", "Building SoCalendar - Part I", "2024-06-23"},
    {"so-calendar-tui", "[WIP] Building SoCalendar - TUI", "2024-12-03"}
  ]

  test "original paths render the correct title, date, description and article", %{conn: conn} do
    for {slug, title, date} <- @posts do
      document = conn |> get("/#{slug}/") |> html_response(200) |> LazyHTML.from_document()

      assert document
             |> LazyHTML.query("#post-#{slug} > header h1")
             |> LazyHTML.text()
             |> String.trim() == title

      assert document |> LazyHTML.query("#post-#{slug} time") |> LazyHTML.attribute("datetime") ==
               [date]

      assert document |> LazyHTML.query("title") |> LazyHTML.text() =~ title
      assert document |> LazyHTML.query("article.prose #post-body p") |> Enum.count() > 0

      assert document |> LazyHTML.query("meta[name=description]") |> LazyHTML.attribute("content") ==
               [PersonalSite.Blog.get_post(slug).description]
    end
  end

  test "missing trailing slashes redirect, but unknown posts return 404", %{conn: conn} do
    assert conn |> get("/particles") |> redirected_to(301) == "/particles/"
    assert_error_sent 404, fn -> get(conn, "/does-not-exist/") end
    assert_error_sent 404, fn -> get(conn, "/does-not-exist") end
  end

  test "all seven article images are accessible and have alt text", %{conn: conn} do
    images =
      Enum.flat_map(PersonalSite.Blog.all_posts(), fn post ->
        post.body |> LazyHTML.from_fragment() |> LazyHTML.query("img") |> Enum.to_list()
      end)

    assert length(images) == 7

    for image <- images do
      [src] = LazyHTML.attribute(image, "src")
      assert String.starts_with?(src, "/images/posts/")
      assert [alt] = LazyHTML.attribute(image, "alt")
      assert String.length(alt) > 10
      response = get(conn, src)
      assert response.status == 200
      assert get_resp_header(response, "content-type") == ["image/png"]
    end

    for {filename, width} <- [
          {"boundaries.png", "500"},
          {"sand.png", "500"},
          {"coloured-teletubbies.png", "382"}
        ] do
      image =
        Enum.find(images, fn image ->
          [src] = LazyHTML.attribute(image, "src")
          String.ends_with?(src, "/" <> filename)
        end)

      assert LazyHTML.attribute(image, "width") == [width]
    end
  end

  test "sitemap lists the homepage and all article URLs with dates", %{conn: conn} do
    response = conn |> put_req_header("accept", "application/xml") |> get("/sitemap.xml")
    assert response.status == 200
    assert [content_type] = get_resp_header(response, "content-type")
    assert content_type =~ "application/xml"
    document = LazyHTML.from_document(response.resp_body)
    entries = LazyHTML.query(document, "url")
    locations = entries |> LazyHTML.query("loc") |> Enum.map(&LazyHTML.text/1)

    assert Enum.sort(locations) ==
             Enum.sort([
               "https://www.samyouatt.dev/"
               | Enum.map(@posts, fn {slug, _, _} -> "https://www.samyouatt.dev/#{slug}/" end)
             ])

    for {slug, _, date} <- @posts do
      entry =
        Enum.find(
          entries,
          &(LazyHTML.text(LazyHTML.query(&1, "loc")) == "https://www.samyouatt.dev/#{slug}/")
        )

      assert entry |> LazyHTML.query("lastmod") |> LazyHTML.text() == date
    end

    assert conn |> get("/robots.txt") |> response(200) =~
             "Sitemap: https://www.samyouatt.dev/sitemap.xml"
  end
end
