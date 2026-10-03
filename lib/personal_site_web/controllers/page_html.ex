defmodule PersonalSiteWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PersonalSiteWeb, :html

  embed_templates "page_html/*"

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
