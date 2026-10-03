defmodule Mix.Tasks.Photos.Publish do
  use Mix.Task

  @shortdoc "Generate photo variants and publish them to R2 (or preview with --dry-run)"
  @moduledoc """
  Usage:

      mix photos.publish path/to/summit.jpg --dry-run
      mix photos.publish path/to/*.jpg --group bealach

  IDs are filename stems: lowercase letters, digits and hyphens only.
  `--group` is optional; `index` is reserved for the ungrouped manifest.
  `--replace` permits changing an existing ID's source image.
  `--srgb-profile PATH` overrides PHOTO_SRGB_PROFILE or the system sRGB profile.

  Requires ImageMagick 7 (`magick`). Publishing also requires rclone and
  PHOTO_R2_DEST, e.g. `r2:site-photos`. Configure credentials privately using
  `rclone config`; never place them in this repository.

  Dry runs generate files and a preview manifest under tmp/photos without
  contacting R2 or changing priv/photos. Publishing writes priv/photos only
  after all uploads succeed. Neither mode uploads original inputs.
  """

  @impl true
  def run(args) do
    {opts, files, invalid} =
      OptionParser.parse(args,
        strict: [dry_run: :boolean, group: :string, replace: :boolean, srgb_profile: :string]
      )

    if invalid != [], do: Mix.raise("Unknown or invalid options: #{inspect(invalid)}")
    Mix.Task.run("app.config")

    result = PersonalSite.Photos.Publisher.publish(files, opts)
    action = if opts[:dry_run], do: "Preview", else: "Published"
    Mix.shell().info("#{action}: #{Enum.join(result.ids, ", ")}")
    Mix.shell().info("Manifest: #{result.manifest}")
    Mix.shell().info("Generated files: #{result.output}")
  end
end
