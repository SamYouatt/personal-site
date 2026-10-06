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

## Publishing photographs to R2

Run the publisher from this checkout on the machine holding your selected exports.
It needs **ImageMagick 7** (`magick`, with JPEG/WebP and LCMS support), an **sRGB ICC
profile**, and **rclone** (1.60 or newer) for uploads. These are publishing tools,
not dependencies of the deployed Phoenix server. On macOS, `brew install
imagemagick rclone` supplies the tools and the system supplies the profile. On
Debian, `icc-profiles-free` supplies `/usr/share/color/icc/sRGB.icc`; ensure your
ImageMagick installation is version 7. Use `--srgb-profile /path/to/sRGB.icc` or
`PHOTO_SRGB_PROFILE` if the profile is elsewhere.

Uploads require an existing bucket and a privately configured rclone remote
(`rclone config`; see [R2 configuration](https://rclone.org/s3/#cloudflare-r2)).
This site uses the `personal-site-images` bucket with the `r2` remote.

```sh
# Generate locally: no credentials or network access required.
mix photos.publish /path/to/summit.jpg --dry-run
mix photos.publish /path/to/*.jpg --group bealach --dry-run

# Upload derivatives to the configured remote and bucket.
export PHOTO_R2_DEST=r2:personal-site-images
mix photos.publish /path/to/summit.jpg
mix photos.publish /path/to/*.jpg --group bealach
```

Use edited JPEG, PNG, TIFF or WebP exports, not RAW files. IDs come from filename
stems and must contain lowercase letters, digits and hyphens, e.g. `summit.jpg`.
Groups follow the same naming rule; `index` is reserved. Duplicate IDs in a batch
are rejected. IDs can repeat in different groups or in the ungrouped collection.
For multi-frame inputs, only the first frame is used.

The task applies orientation, converts embedded ICC colour to sRGB, strips source
metadata (including EXIF GPS, XMP, comments and copyright), and reattaches only the
sRGB profile. Untagged exports are assumed to be sRGB. Add public captions, credit
and alt text explicitly in your page content. Input files are never changed or
uploaded. Each photo produces JPEG and WebP at 640, 1280 and 1920 px widths, plus
an uncropped lightbox version bounded by 3200 × 3200 px. Images are never upscaled.

Generated files live under ignored `tmp/photos/`. A dry run writes a preview
manifest to `tmp/photos/manifests/index.json` (or `<group>.json`) and never modifies
the published manifest. After a successful upload, the task merges photo entries
into `priv/photos/index.json` (or `<group>.json`). Commit these small manifests
with the page content; **do not commit photo originals or credentials**.

Each manifest contains `version`, `group` and a `photos` map keyed by readable ID.
Photo entries contain source SHA-256, recipe version, oriented dimensions and
variants with `key`, `width`, `height`, `format`, `role` and byte count. The `key`
is relative to the bucket; join it to the public image domain for a URL. Grouped
keys start with `photos/<group>/`; ungrouped keys use `photos/_ungrouped/`. Output
content hashes make URLs immutable. Consumers should deduplicate equal widths in
`srcset` for small inputs.

The `/photos` page displays photos from the manifest, with new IDs appended after
the curated `@photo_order` in ID order. Page metadata is collection-agnostic; the
current collection heading is “North Coast 500”. Photos are deduplicated by source
SHA-256, excluding the similar Whaligoe
boat shot (`nc500-whaligoe-boat`) without deleting its uploaded assets. The gallery pairs portraits
side by side and gives landscapes the full width on wider screens; narrow screens
use one column. The curated order in `PageController` spaces portrait pairs between
landscape runs, opens with Eilean Donan, and puts Neist Point in the first portrait
pair. Black-and-white images fall every third desktop row, with the castles together. The gallery is capped
at 1.5× the body-text width. Each photo has responsive WebP/JPEG sources and a full-image dialog. The
larger JPEG is requested only when opened; the image link still works without JavaScript.
While a dialog is open, Left/Right arrow keys move through the gallery without wrapping
past the first or last photo. Escape closes it and returns focus to the current photo.
Set
`PHOTO_BASE_URL` to the bucket's public HTTPS origin when starting Phoenix, e.g.
`PHOTO_BASE_URL=https://photos.samyouatt.dev mix phx.server` **after** connecting
that domain in Cloudflare. The S3 API endpoint is authenticated storage access,
not a public image origin. Without `PHOTO_BASE_URL`, the page shows a placeholder
message. No credentials are needed by Phoenix or sent to browsers. Publishing a
manifest does not deploy it; page/manifest changes still need the usual release.
Markdown photo integration is not included yet.

Set the optional `mat` attribute on `<.photo_print>` in
`lib/personal_site_web/controllers/page_html/photos.html.heex` to add white digital
matting in the lightbox. `photo_mat/2` in `PageHTML` selects 3% for landscapes and
6% for portraits, except Eilean Donan, Ard Neackie, Base of Storr, Strathy Beach,
Dunrobin, the waterfall, the blue-sky lighthouse, the black-and-white Chanonry boat,
and Rhue lighthouse, which have no mat.
Values are percentages of the **unmatted image width**
on every side, so equal numbers mean equal border widths even on portrait photos:

- Omit `mat` or use `mat={0}` for no mat.
- `mat={6}` or `mat={[6]}` gives 6% on every side.
- `mat={[4, 6]}` gives 4% top/bottom and 6% left/right.
- `mat={[4, 6, 10]}` gives 4% top, 6% left/right, 10% bottom.
- `mat={[4, 6, 10, 8]}` gives top/right/bottom/left individually.

Use non-negative numbers; fractional values are supported. The photo and mat
scale as one composition to fit the lightbox, without cropping. The mat stays
white in either theme and does not affect the gallery thumbnail or uploaded
files. These inline settings survive republishing because they are not stored in
the generated manifest. The no-JavaScript image link still opens the original
unmatted derivative. This does not add zoom controls.

Reruns regenerate variants, but rclone skips checksum-matching uploaded files.
Changed source contents under an existing ID require `--replace`. Files omitted
from a command are retained; old object versions are not deleted. Uploads retry
three times. Rerunning an interrupted batch skips completed matching objects and
retries remaining files; this is not a promise of byte-level resume after process
exit. The manifest changes only after all selected uploads succeed, so a failed
batch may leave unreferenced objects but no partially published manifest. Run one
publisher at a time per checkout. After a hard kill, remove
`tmp/photos/.publish-lock` only once you have confirmed no publisher is running.

The task sets `Cache-Control: public,max-age=31536000,immutable` on derivatives;
rclone infers their image content types. Once connected, verify actual response
headers and cache behavior on the custom domain. No CORS configuration is needed
for ordinary cross-origin `<img>` display (canvas/fetch use would be separate).
Live R2 credentials, permissions, headers and CDN delivery must be checked against
the configured bucket; local processing alone does not validate those.

### Photo heading artwork

The castle rule uses the Painter → AutoTrace **centreline** pipeline recovered from
the [NC500 map experiment](https://ampcode.com/threads/T-01a0cf92-411b-744f-a5e3-fc8ebf343d9a).
`assets/art/nc500-castle-source.png` is the `300x76+1120+485` crop of option B in
the [selected Painter sheet](https://ampcode.com/user-content/attachments/e76b3ea0a8e70463e7ab06ed377e5352ea012b75fff19c7dbcf08d07da10ea32-file.png).
`scripts/build_photo_rule.py` resizes it to 1200px, thresholds at 65%, traces with
six filter iterations and error threshold 2, and rounds coordinates to one decimal.
The tighter fit preserves the battlements; no castle paths are hand-redrawn.
CSS extends the baseline and uses the generated SVG as a theme-aware mask.

To regenerate, install ImageMagick 7 plus these AutoTrace build dependencies:
`build-essential autoconf automake libtool pkg-config intltool autopoint gettext
libglib2.0-dev libpng-dev`. Then:

```sh
git clone https://github.com/autotrace/autotrace /tmp/autotrace
git -C /tmp/autotrace checkout fca2c54a2dbd0518fd78595d8d7bc20326fd9094
(cd /tmp/autotrace && ./autogen.sh &&
  ./configure --prefix=/tmp/autotrace-install --without-magick --without-pstoedit &&
  make -j4 && make install)
python3 scripts/build_photo_rule.py --autotrace /tmp/autotrace-install/bin/autotrace
```

Use `--error-threshold 6 --output /tmp/castle-smooth.svg` to compare a smoother fit.
Only the resulting `priv/static/images/nc500-castle.svg` is needed at runtime.

The heading uses self-hosted Crimson Pro Light (300), selected as option 7 in the
blind serif comparison. Its SIL Open Font License is at
`priv/static/fonts/CrimsonPro-OFL.txt`. The WOFF2 contains the Latin subset;
other characters fall back to Georgia or the browser's serif font.
To download the same font file:

```sh
curl -fsSL 'https://fonts.gstatic.com/s/crimsonpro/v28/q5uUsoa5M_tv7IihmnkabC5XiXCAlXGks1WZkG1MP5s-.woff2' -o priv/static/fonts/CrimsonPro-Light.woff2
```

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
