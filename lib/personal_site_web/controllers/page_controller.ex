defmodule PersonalSiteWeb.PageController do
  use PersonalSiteWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
