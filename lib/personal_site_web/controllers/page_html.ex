defmodule PersonalSiteWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PersonalSiteWeb, :html

  embed_templates "page_html/*"

  attr :id, :string, default: "photo-lightbox"
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
    <div id={"#{@id}-print"} class="photo-print" style={@style}>
      <img
        id={"#{@id}-image"}
        data-src={photo_url(@base_url, photo_variant(@photo, "lightbox", "jpg"))}
        width={@photo["width"]}
        height={@photo["height"]}
        alt={@alt}
      />
    </div>
    """
  end

  defp photo_alt(id) do
    %{
      "nc500-ard-neackie" =>
        "Ard Neackie jutting into the loch beneath heavy clouds, in black and white",
      "nc500-base-of-storr" => "Sunlight and mist across the hills below the Old Man of Storr",
      "nc500-bouy-bench" => "A red lifebuoy beside a weathered bench above a stony beach",
      "nc500-bw-old-wick-castle" =>
        "Looking up at the stone ruins of Old Wick Castle, in black and white",
      "nc500-bw-strathy-beach" =>
        "A lone figure on Strathy Beach beneath dark hills, in black and white",
      "nc500-cemetry-near-chocolate" =>
        "Gravestones surrounding a ruined church, in black and white",
      "nc500-chanonry-point-boat" =>
        "A small boat on the shore below Chanonry Point lighthouse, in black and white",
      "nc500-clouded-ben-loyal" => "Low cloud over Ben Loyal and a dark hillside",
      "nc500-dunrobbin" => "The pale towers of Dunrobin Castle against a blue sky",
      "nc500-eliean-donan-landscape" => "Eilean Donan Castle across seaweed-covered shallows",
      "nc500-falls-long-exposure" => "Water cascading over rocks beneath overhanging trees",
      "nc500-hilltop-boats" => "Small boats moored on a loch surrounded by rocky hills",
      "nc500-hilltop-sheep" => "Sheep grazing on a grassy hill beneath an overcast sky",
      "nc500-lighthouse-blue-sky" =>
        "A white lighthouse above a stone wall beneath a blue and cloudy sky",
      "nc500-neist-point-cliff" => "A sheer grassy cliff above the sea at Neist Point on Skye",
      "nc500-random-layby" => "A narrow footbridge crossing a river through golden moorland",
      "nc500-rhue-lighthouse" => "Looking up at Rhue lighthouse against a clear blue sky",
      "nc500-urquhart-castle" =>
        "The ruins of Urquhart Castle overlooking Loch Ness, in black and white",
      "nc500-whaligoe-boat" => "A small orange boat beneath the towering cliffs at Whaligoe",
      "nc500-whaligoe-cliff" => "Sunlight on the grassy clifftops above the sea at Whaligoe"
    }
    |> Map.get(id, "Photograph — " <> String.replace(id, "-", " "))
  end

  defp photo_url(base_url, variant),
    do: String.trim_trailing(base_url, "/") <> "/" <> variant["key"]

  defp photo_mat(id, photo) do
    cond do
      id in ~w(nc500-eliean-donan-landscape nc500-ard-neackie nc500-base-of-storr
               nc500-bw-strathy-beach nc500-dunrobbin nc500-falls-long-exposure
               nc500-lighthouse-blue-sky nc500-chanonry-point-boat nc500-rhue-lighthouse) ->
        0

      photo["width"] >= photo["height"] ->
        3

      true ->
        6
    end
  end

  defp photo_sizes(photo) do
    if photo["width"] >= photo["height"] do
      "(min-width: 640px) min(97.5ch, calc(100vw - 4rem)), calc(100vw - 2rem)"
    else
      "(min-width: 768px) min(calc(48.75ch - 0.5rem), calc(50vw - 2.5rem)), (min-width: 640px) calc(100vw - 4rem), calc(100vw - 2rem)"
    end
  end

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
