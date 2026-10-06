defmodule PersonalSiteWeb.PageController do
  use PersonalSiteWeb, :controller

  # Monochrome every third row; portrait pairs break up the landscapes.
  @photo_order ~w(
    nc500-eliean-donan-landscape nc500-ard-neackie
    nc500-neist-point-cliff nc500-hilltop-sheep
    nc500-base-of-storr nc500-bw-strathy-beach
    nc500-dunrobbin nc500-falls-long-exposure
    nc500-bw-old-wick-castle nc500-urquhart-castle
    nc500-clouded-ben-loyal nc500-lighthouse-blue-sky
    nc500-cemetry-near-chocolate nc500-random-layby
    nc500-bouy-bench nc500-hilltop-boats
    nc500-chanonry-point-boat nc500-rhue-lighthouse nc500-whaligoe-cliff
  ) |> Enum.with_index() |> Map.new()

  def home(conn, _params) do
    render(conn, :home, posts: PersonalSite.Blog.all_posts(), page_title: "Writing")
  end

  def photos(conn, _params) do
    manifest =
      Application.app_dir(:personal_site, "priv/photos/index.json")
      |> File.read!()
      |> Jason.decode!()

    photos =
      manifest["photos"]
      |> Enum.reject(fn {id, _photo} -> id == "nc500-whaligoe-boat" end)
      |> Enum.sort_by(fn {id, _photo} ->
        {Map.get(@photo_order, id, map_size(@photo_order)), id}
      end)
      |> Enum.uniq_by(fn {_id, photo} -> photo["source_sha256"] end)

    render(conn, :photos,
      page_title: "Photos",
      description: "Photographs by Sam Youatt.",
      photos: photos,
      photo_base_url: Application.get_env(:personal_site, :photo_base_url)
    )
  end
end
