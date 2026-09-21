defmodule PersonalSite.Blog do
  @moduledoc "Git-backed articles, rendered once when the application compiles."

  use NimblePublisher,
    build: PersonalSite.Blog.Post,
    from: Application.app_dir(:personal_site, "priv/posts/*.md"),
    as: :posts,
    comrak_options: [
      extension: [strikethrough: true, header_id_prefix: ""],
      # Only trusted repository content is rendered; embeds require raw HTML.
      render: [unsafe: true, github_pre_lang: true, full_info_string: true],
      syntax_highlight: [
        engine: :lumis,
        opts:
          [
            formatter:
              {:html_multi_themes,
               themes: [light: "xcode_light", dark: "catppuccin_mocha"],
               default_theme: "light-dark()"}
          ]
          |> Lumis.validate_options!()
          |> Lumis.rust_options!()
      ]
    ]

  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  def all_posts, do: @posts
  def get_post(slug), do: Enum.find(all_posts(), &(&1.slug == slug))
end
