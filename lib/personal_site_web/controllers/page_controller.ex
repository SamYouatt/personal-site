defmodule PersonalSiteWeb.PageController do
  use PersonalSiteWeb, :controller

  def home(conn, _params) do
    render(conn, :home, posts: PersonalSite.Blog.all_posts(), page_title: "Writing")
  end
end
