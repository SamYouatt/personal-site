# PersonalSite

Use Elixir 1.20.4 with Erlang/OTP 29.1 (the versions installed by `.agents/setup`).

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Writing posts

Add `priv/posts/your-slug.md`. The filename determines the URL, `/your-slug/`.
Posts use NimblePublisher's native metadata followed by Markdown:

```elixir
%{
  title: "A new post",
  date: ~D[2026-09-20],
  description: "A short description for the post index."
}
---
Your Markdown here.
```

Posts compile to HTML using MDExNative and Lumis. Code fences accept language names
such as `rust`, `kotlin`, or `scss`, and decorators such as `highlight_lines="2-4"`.
Store images in `priv/static/images/posts/<slug>/` and reference them in Markdown
as `/images/posts/<slug>/image.png`. Use an HTML `<img>` with `alt` and `width`
attributes when a smaller display size is needed; no image processing is required.
The article body is styled with Tailwind Typography; `mix setup` installs its npm dependency.

Only commit trusted content: native metadata is evaluated as Elixir, and raw HTML
is allowed for embeds. Post bodies are not evaluated as HEEx. Publishing requires
rebuilding and deploying the app; no database is used.

Run `mix precommit` for compilation, formatting, and tests. In an orb, run
`.agents/setup`, then `amp orb services ensure` for the supervised preview and portal URL.
No production deployment or domain changes are included in this migration.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
