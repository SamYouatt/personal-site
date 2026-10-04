defmodule PersonalSiteWeb.PhotoPrintTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  alias PersonalSiteWeb.PageHTML

  @photo %{
    "width" => 400,
    "height" => 600,
    "variants" => [%{"role" => "lightbox", "format" => "jpg", "key" => "photo.jpg"}]
  }

  test "no mat by default and the larger image stays lazy" do
    document = print()
    assert_geometry(document, 400, 600, 0, 0, 400, 600)
    image = LazyHTML.query(document, "#photo-lightbox-image")
    assert LazyHTML.attribute(image, "src") == []
    assert LazyHTML.attribute(image, "data-src") == ["https://photos.example/photo.jpg"]
    assert LazyHTML.attribute(image, "alt") == ["Test photograph"]
    assert_geometry(print(mat: 0), 400, 600, 0, 0, 400, 600)
  end

  test "one value gives physically equal borders on a portrait image" do
    for mat <- [5, [5]] do
      assert_geometry(print(mat: mat), 440, 640, 20, 20, 400, 600)
    end
  end

  test "two values mean vertical then horizontal, both relative to image width" do
    assert_geometry(print(mat: [5, 10]), 480, 640, 20, 40, 400, 600)
  end

  test "three values allow bottom weighting" do
    assert_geometry(print(mat: [5, 10, 15]), 480, 680, 20, 40, 400, 600)
  end

  test "four asymmetric values preserve CSS order and fractional widths" do
    assert_geometry(print(mat: [2.5, 5, 10, 15]), 480, 650, 10, 60, 400, 600)
  end

  test "landscape dimensions preserve the full uncropped image" do
    photo = %{@photo | "width" => 800, "height" => 400}
    assert_geometry(print(photo: photo, mat: [5, 10]), 960, 480, 40, 80, 800, 400)
  end

  test "invalid author settings fail clearly" do
    for mat <- [-1, [5, -2], [], [1, 2, 3, 4, 5], "6", [nil]] do
      assert_raise ArgumentError, ~r/mat/, fn -> print(mat: mat) end
    end
  end

  defp print(options \\ []) do
    assigns =
      Keyword.merge(
        [photo: @photo, base_url: "https://photos.example/", alt: "Test photograph"],
        options
      )

    render_component(&PageHTML.photo_print/1, assigns) |> LazyHTML.from_fragment()
  end

  defp assert_geometry(document, width, height, top, left, image_width, image_height) do
    [style] = document |> LazyHTML.query("#photo-lightbox-print") |> LazyHTML.attribute("style")

    values =
      Regex.scan(~r/--photo-([\w-]+): ([\d.]+)/, style)
      |> Map.new(fn [_, name, value] -> {name, String.to_float(value)} end)

    assert_in_delta values["ratio"], width / height, 0.000001
    assert_in_delta values["top"] * height / 100, top, 0.000001
    assert_in_delta values["left"] * width / 100, left, 0.000001
    assert_in_delta values["width"] * width / 100, image_width, 0.000001
    assert_in_delta values["height"] * height / 100, image_height, 0.000001
  end
end
