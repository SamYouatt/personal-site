defmodule PersonalSiteWeb.SitemapController do
  use PersonalSiteWeb, :controller

  def index(conn, _params) do
    posts =
      Enum.map_join(PersonalSite.Blog.all_posts(), fn post ->
        "<url><loc>https://www.samyouatt.dev/#{post.slug}/</loc>" <>
          "<lastmod>#{Date.to_iso8601(post.date)}</lastmod></url>"
      end)

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url><loc>https://www.samyouatt.dev/</loc></url>
      #{posts}
    </urlset>
    """

    conn |> put_resp_content_type("application/xml") |> send_resp(200, xml)
  end
end
