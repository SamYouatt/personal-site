defmodule PersonalSiteWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PersonalSiteWeb, :html

  embed_templates "page_html/*"

  attr :photo, :map, required: true
  attr :base_url, :string, required: true
  attr :alt, :string, required: true
  attr :mat, :any, default: 0

  def photo_print(assigns) do
    sides =
      case assigns.mat do
        value when is_number(value) -> [value, value, value, value]
        [all] -> [all, all, all, all]
        [vertical, horizontal] -> [vertical, horizontal, vertical, horizontal]
        [top, horizontal, bottom] -> [top, horizontal, bottom, horizontal]
        [top, right, bottom, left] -> [top, right, bottom, left]
        _ -> raise ArgumentError, "mat must be a number or a list of one to four numbers"
      end

    unless Enum.all?(sides, &(is_number(&1) && &1 >= 0)) do
      raise ArgumentError, "mat values must be non-negative numbers"
    end

    [top, right, bottom, left] = sides
    image_height = 100 * assigns.photo["height"] / assigns.photo["width"]
    width = left + 100 + right
    height = top + image_height + bottom

    assigns =
      assign(assigns, :style, """
      --photo-ratio: #{width / height};
      --photo-top: #{100 * top / height}%;
      --photo-left: #{100 * left / width}%;
      --photo-width: #{100 * 100 / width}%;
      --photo-height: #{100 * image_height / height}%;
      """)

    ~H"""
    <div id="photo-lightbox-print" class="photo-print" style={@style}>
      <img
        id="photo-lightbox-image"
        data-src={photo_url(@base_url, photo_variant(@photo, "lightbox", "jpg"))}
        width={@photo["width"]}
        height={@photo["height"]}
        alt={@alt}
      />
    </div>
    """
  end

  defp photo_url(base_url, variant),
    do: String.trim_trailing(base_url, "/") <> "/" <> variant["key"]

  defp photo_srcset(base_url, photo, format) do
    photo["variants"]
    |> Enum.filter(&(&1["role"] == "responsive" && &1["format"] == format))
    |> Enum.uniq_by(& &1["width"])
    |> Enum.sort_by(& &1["width"])
    |> Enum.map_join(", ", &(photo_url(base_url, &1) <> " #{&1["width"]}w"))
  end

  defp photo_variant(photo, role, format) do
    Enum.find(photo["variants"], &(&1["role"] == role && &1["format"] == format))
  end
end
