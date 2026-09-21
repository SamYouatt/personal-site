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

## Deploying to Fly.io

The `samyouatt-site` app runs one always-on shared-CPU machine with 256 MB RAM in
London. There is no database or persistent volume. The public address is
https://www.samyouatt.dev. The apex domain redirects to `www`, preserving paths
and queries. https://samyouatt-site.fly.dev remains available for diagnostics.

The Docker build installs npm dependencies, compiles posts and assets, and packages
an Elixir release. Only the release and runtime libraries enter the final image.
`SECRET_KEY_BASE` is stored as a Fly secret, never in the repository or image.

After installing `flyctl` and authenticating with an app-scoped deploy token:

```sh
mix precommit
fly deploy --remote-only --ha=false
fly status
fly checks list
```

Keep `--ha=false` on deployments to avoid provisioning a spare machine. There is
no automatic deployment on Git pushes. In Amp, if the setup credential is named
`FLY_ORG_TOKEN`, pass it as `FLY_API_TOKEN` to Fly commands without printing it.
Replace the temporary organisation token with an app-scoped token after setup.

Keep the `_acme-challenge` CNAME records for both the apex and `www` so Fly can
renew their certificates. Preserve unrelated DNS records, particularly mail records.

To roll back to the retained GitHub Pages deployment, first verify that its custom
domain and HTTPS certificate are ready, then restore the `www` CNAME to
`samyouatt.github.io` and the saved apex DNS configuration. Keep Fly running while
cached DNS records expire. Copy any new Phoenix-only posts back to Zola if needed.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
