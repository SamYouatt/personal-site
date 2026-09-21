defmodule PersonalSiteWeb.EndpointTest do
  use PersonalSiteWeb.ConnCase, async: true

  test "apex redirects preserve paths and encoded queries, including static files", %{conn: conn} do
    for path <- ["/", "/particles/?source=a%2Fb&tag=one&tag=two", "/robots.txt"] do
      response = get(conn, "https://samyouatt.dev" <> path)

      assert redirected_to(response, 308) == "https://www.samyouatt.dev" <> path
      assert response.halted
    end
  end

  test "www, the Fly hostname, and local development do not redirect", %{conn: conn} do
    for host <- ["www.samyouatt.dev", "samyouatt-site.fly.dev", "localhost"] do
      response = get(conn, "http://#{host}/")

      assert response.status == 200
      assert get_resp_header(response, "location") == []
    end
  end
end
