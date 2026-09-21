defmodule PersonalSiteWeb.BlogController do
  use PersonalSiteWeb, :controller

  alias PersonalSite.Blog

  def show(conn, %{"slug" => slug}) do
    case Blog.get_post(slug) do
      nil ->
        raise PersonalSiteWeb.BlogNotFoundError

      post ->
        if String.ends_with?(conn.request_path, "/") do
          render(conn, :show, post: post, page_title: post.title, description: post.description)
        else
          conn |> put_status(:moved_permanently) |> redirect(to: ~p"/#{slug}/")
        end
    end
  end
end
