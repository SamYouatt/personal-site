defmodule PersonalSiteWeb.PageController do
  use PersonalSiteWeb, :controller

  # Portrait pairs break up the landscapes. Monochrome every third row in NC500,
  # and every three or four rows in San Francisco, ending with the bridge at night.
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
    sf-bay-view-street sf-hilltop-cars
    sf-bw-embarcadero-center sf-bw-golden-gate-tower
    sf-california-street sf-alcatraz-island sf-bw-in-n-out
    sf-garden-steps sf-hillside-convertible
    sf-ferry-deck sf-golden-gate-onlookers sf-bw-sfmoma-terrace
    sf-golden-gate-bridge sf-fishing-boat
    sf-lime-point-lighthouse sf-palace-fine-arts
    sf-bw-glass-bottles sf-bw-sfmoma-staircase
    sf-golden-gate-night
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

    {sf_photos, nc500_photos} =
      Enum.split_with(photos, fn {id, _photo} -> String.starts_with?(id, "sf-") end)

    render(conn, :photos,
      page_title: "Photos",
      description: "Photographs by Sam Youatt.",
      photos: photos,
      nc500_photos: nc500_photos,
      sf_photos: sf_photos,
      photo_base_url: Application.get_env(:personal_site, :photo_base_url)
    )
  end
end
