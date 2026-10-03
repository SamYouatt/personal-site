defmodule PersonalSiteWeb.PageController do
  use PersonalSiteWeb, :controller

  def home(conn, _params) do
    render(conn, :home, posts: PersonalSite.Blog.all_posts(), page_title: "Writing")
  end

  def photos(conn, _params) do
    manifest =
      Application.app_dir(:personal_site, "priv/photos/index.json")
      |> File.read!()
      |> Jason.decode!()

    render(conn, :photos,
      page_title: "Photos",
      description: "Photographs by Sam Youatt.",
      photo: Map.fetch!(manifest["photos"], "nc500-skye-hill"),
      photo_base_url: Application.get_env(:personal_site, :photo_base_url)
    )
  end
end
