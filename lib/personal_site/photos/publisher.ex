defmodule PersonalSite.Photos.Publisher do
  @moduledoc false

  @recipe "web-v1"
  @formats [{"webp", "82"}, {"jpg", "85"}]

  def publish(files, opts \\ []) do
    if files == [], do: raise(ArgumentError, "Supply at least one image file")
    group = opts[:group]
    if group, do: validate_name!(group)
    if group == "index", do: raise(ArgumentError, "The group name index is reserved")

    root = File.cwd!()
    directory = Path.join(root, "priv/photos")
    output = Path.join(root, "tmp/photos")
    File.mkdir_p!(output)
    lock = Path.join(output, ".publish-lock")

    case File.mkdir(lock) do
      :ok -> :ok
      {:error, :eexist} -> raise "Another publisher is running (lock: #{lock})"
      {:error, reason} -> raise File.Error, reason: reason, action: "lock", path: lock
    end

    try do
      manifest_path = Path.join(directory, "#{group || "index"}.json")
      existing = read_manifest(manifest_path, group)
      inputs = Enum.map(files, &input!/1)
      ids = Enum.map(inputs, & &1.id)

      if length(Enum.uniq(ids)) != length(ids),
        do: raise(ArgumentError, "Duplicate photo IDs in this batch")

      Enum.each(inputs, fn input ->
        previous = existing["photos"][input.id]

        if previous && previous["source_sha256"] != input.hash && !opts[:replace],
          do:
            raise(
              ArgumentError,
              "#{input.id} already exists with different contents; use --replace"
            )
      end)

      profile = profile!(opts)
      destination = if !opts[:dry_run], do: destination!()

      photos =
        Map.new(inputs, fn input ->
          {input.id, generate!(input, group, output, profile)}
        end)

      unless opts[:dry_run] do
        for {_id, photo} <- photos, variant <- photo["variants"] do
          upload!(Path.join(output, variant["key"]), "#{destination}/#{variant["key"]}")
        end
      end

      manifest = %{existing | "photos" => Map.merge(existing["photos"], photos)}

      target =
        if opts[:dry_run],
          do: Path.join(output, "manifests/#{group || "index"}.json"),
          else: manifest_path

      atomic_write!(target, Jason.encode!(manifest, pretty: true) <> "\n")
      %{ids: ids, manifest: target, output: output}
    after
      File.rm_rf!(lock)
    end
  end

  defp input!(path) do
    path = Path.expand(path)
    id = path |> Path.basename() |> Path.rootname()
    validate_name!(id)

    unless String.downcase(Path.extname(path)) in ~w(.jpg .jpeg .png .tif .tiff .webp),
      do: raise(ArgumentError, "Use an edited JPEG, PNG, TIFF or WebP export: #{id}")

    %{id: id, path: path, hash: hash(File.read!(path))}
  end

  defp validate_name!(name) do
    unless Regex.match?(~r/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, name),
      do: raise(ArgumentError, "Names must use lowercase letters, digits and hyphens: #{name}")
  end

  defp read_manifest(path, group) do
    case File.read(path) do
      {:ok, json} ->
        case Jason.decode!(json) do
          %{"version" => 1, "group" => ^group, "photos" => photos} = manifest
          when is_map(photos) ->
            manifest

          _ ->
            raise "Unsupported photo manifest: #{path}"
        end

      {:error, :enoent} ->
        %{"version" => 1, "group" => group, "photos" => %{}}

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read", path: path
    end
  end

  defp profile!(opts) do
    profile =
      opts[:srgb_profile] || System.get_env("PHOTO_SRGB_PROFILE") ||
        Enum.find(
          [
            "/usr/share/color/icc/sRGB.icc",
            "/System/Library/ColorSync/Profiles/sRGB Profile.icc"
          ],
          &File.regular?/1
        )

    unless profile && File.regular?(profile),
      do: raise("Supply an sRGB ICC profile with --srgb-profile or PHOTO_SRGB_PROFILE")

    Path.expand(profile)
  end

  defp generate!(input, group, output, profile) do
    work = Path.join(output, ".publish-lock")
    normalized = Path.join(work, "normalized.miff")

    # Convert embedded ICC colour before stripping metadata. Untagged exports
    # are assumed sRGB. Reattach only the known sRGB profile after stripping.
    magick!([
      input.path <> "[0]",
      "-auto-orient",
      "-profile",
      profile,
      "-strip",
      "-profile",
      profile,
      normalized
    ])

    {width, height} = dimensions!(normalized)

    sizes =
      for width <- [640, 1280, 1920], do: {"w#{width}", "#{width}x>"}

    variants =
      for {size, geometry} <- sizes ++ [{"lightbox", "3200x3200>"}],
          {format, quality} <- @formats do
        file = Path.join(work, "#{size}.#{format}")
        magick!([normalized, "-resize", geometry, "-quality", quality, file])
        bytes = File.read!(file)
        {w, h} = dimensions!(file)
        key = "photos/#{group || "_ungrouped"}/#{input.id}/#{hash(bytes)}/#{size}.#{format}"
        atomic_write!(Path.join(output, key), bytes)

        %{
          "key" => key,
          "width" => w,
          "height" => h,
          "format" => format,
          "role" => if(size == "lightbox", do: "lightbox", else: "responsive"),
          "bytes" => byte_size(bytes)
        }
      end

    %{
      "source_sha256" => input.hash,
      "recipe" => @recipe,
      "width" => width,
      "height" => height,
      "variants" => variants
    }
  end

  defp dimensions!(file) do
    [width, height] = magick!(["identify", "-format", "%w %h", file]) |> String.split()
    {String.to_integer(width), String.to_integer(height)}
  end

  defp magick!(args), do: command!("magick", args)

  defp destination! do
    destination = System.get_env("PHOTO_R2_DEST") || ""

    unless Regex.match?(~r/\A[a-zA-Z0-9_-]+:[a-z0-9][a-z0-9.-]+\z/, destination),
      do: raise("Set PHOTO_R2_DEST to a configured rclone remote and bucket, e.g. r2:site-photos")

    destination
  end

  defp upload!(file, destination) do
    command!("rclone", [
      "copyto",
      file,
      destination,
      "--checksum",
      "--immutable",
      "--retries",
      "3",
      "--s3-no-check-bucket",
      "--header-upload",
      "Cache-Control: public,max-age=31536000,immutable"
    ])
  end

  defp command!(executable, args) do
    path = System.find_executable(executable) || raise("Install #{executable} before publishing")

    case System.cmd(path, args, stderr_to_stdout: true) do
      {output, 0} -> output
      {_output, status} -> raise "#{executable} failed (exit #{status}); manifest was not updated"
    end
  end

  defp atomic_write!(path, contents) do
    File.mkdir_p!(Path.dirname(path))
    temporary = path <> ".tmp"
    File.write!(temporary, contents)
    File.rename!(temporary, path)
  end

  defp hash(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end
