defmodule PersonalSiteWeb.PageControllerTest do
  use PersonalSiteWeb.ConnCase, async: false

  setup do
    previous = Application.get_env(:personal_site, :photo_base_url)
    Application.put_env(:personal_site, :photo_base_url, "https://photos.example")
    on_exit(fn -> Application.put_env(:personal_site, :photo_base_url, previous) end)
  end

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

  test "San Francisco follows NC500 with its own ordered gallery and paired portraits", %{
    conn: conn
  } do
    document = conn |> get(~p"/photos/") |> html_response(200) |> LazyHTML.from_document()

    section = LazyHTML.query(document, "#photos + #san-francisco")
    assert LazyHTML.attribute(section, "aria-labelledby") == ["san-francisco-title"]

    assert section |> LazyHTML.query("h2#san-francisco-title") |> LazyHTML.text() |> String.trim() ==
             "San Francisco"

    assert section
           |> LazyHTML.query("#san-francisco-title-rule")
           |> LazyHTML.attribute("aria-hidden") == ["true"]

    ids = section |> LazyHTML.query("#sf-photo-gallery > figure") |> LazyHTML.attribute("id")
    assert length(ids) == 19
    assert length(Enum.uniq(ids)) == 19
    assert hd(ids) == "photo-sf-bay-view-street"
    assert List.last(ids) == "photo-sf-golden-gate-night"
    assert Enum.all?(ids, &String.starts_with?(&1, "photo-sf-"))

    nc500_ids = document |> LazyHTML.query("#photo-gallery > figure") |> LazyHTML.attribute("id")
    assert length(nc500_ids) == 19
    assert hd(nc500_ids) == "photo-nc500-eliean-donan-landscape"
    assert Enum.all?(nc500_ids, &String.starts_with?(&1, "photo-nc500-"))

    portrait_runs =
      section
      |> LazyHTML.query("#sf-photo-gallery img")
      |> Enum.chunk_by(fn image ->
        [width] = LazyHTML.attribute(image, "width")
        [height] = LazyHTML.attribute(image, "height")
        String.to_integer(height) > String.to_integer(width)
      end)
      |> Enum.filter(fn [image | _] ->
        [width] = LazyHTML.attribute(image, "width")
        [height] = LazyHTML.attribute(image, "height")
        String.to_integer(height) > String.to_integer(width)
      end)

    assert Enum.map(portrait_runs, &length/1) == [2, 2, 2, 2]

    for id <- ids do
      [target] = document |> LazyHTML.query("##{id} a") |> LazyHTML.attribute("aria-controls")
      image = LazyHTML.query(document, "##{target} img")
      assert LazyHTML.attribute(image, "src") == []
      assert [url] = LazyHTML.attribute(image, "data-src")
      assert String.starts_with?(url, "https://photos.example/")
    end
  end

  test "photo headings remain available without a configured image origin", %{conn: conn} do
    Application.delete_env(:personal_site, :photo_base_url)
    document = conn |> get(~p"/photos/") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#photos-unavailable") |> Enum.count() == 1
    assert document |> LazyHTML.query("#san-francisco-title") |> Enum.count() == 1

    assert document |> LazyHTML.query("#photo-gallery, #sf-photo-gallery, dialog") |> Enum.count() ==
             0
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

  test "versioned favicon filenames are served as static assets", %{conn: conn} do
    filename = "favicon-test-#{System.unique_integer([:positive])}.ico"
    path = Application.app_dir(:personal_site, "priv/static/#{filename}")
    icon = File.read!("priv/static/favicon.ico")
    on_exit(fn -> File.rm!(path) end)
    File.write!(path, icon)

    assert conn |> get("/#{filename}?vsn=d") |> response(200) == icon
  end
end
