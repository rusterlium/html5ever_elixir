defmodule Html5ever.Precompiled do
  @moduledoc false

  require Logger

  @available_targets ~w(
    aarch64-apple-darwin
    x86_64-apple-darwin
    x86_64-unknown-linux-gnu
    x86_64-unknown-linux-musl
    arm-unknown-linux-gnueabihf
    aarch64-unknown-linux-gnu
    x86_64-pc-windows-msvc
    x86_64-pc-windows-gnu
  )
  @available_nif_versions ~w(2.14 2.15 2.16)
  @checksum_algo :sha256
  @checksum_algorithms [@checksum_algo]

  @native_dir "priv/native"

  def available_targets do
    for target_triple <- @available_targets, nif_version <- @available_nif_versions do
      "nif-#{nif_version}-#{target_triple}"
    end
  end

  @doc """
  Returns URLs for NIFs based on its module name

  The module name is the one that defined the NIF and this information
  is stored in a metadata file.
  """
  def available_nif_urls(module_name) do
    metadata = read_map_from_file_safely(metadata_file())

    case metadata[module_name] do
      %{base_url: base_url, basename: basename, version: version} ->
        for target <- available_targets() do
          # We need to build again the name because each arch is different.
          lib_name = "#{lib_prefix(target)}#{basename}-v#{version}-#{target}"

          tar_gz_file_url(base_url, lib_name_with_ext(target, lib_name))
        end

      _ ->
        raise "metadata about current target for the module #{inspect(module_name)} is not available. Please compile the project again with: `mix compile --force`"
    end
  end

  def current_target_nif_url(module_name) do
    metadata = read_map_from_file_safely(metadata_file())

    case metadata[module_name] do
      %{base_url: base_url, file_name: file_name} ->
        tar_gz_file_url(base_url, file_name)

      _ ->
        raise "metadata about current target for the module #{inspect(module_name)} is not available. Please compile the project again with: `mix compile --force`"
    end
  end

  @doc """
  Returns the target triple for download or compile and load.

  This function is translating and adding more info to the system
  architecture returned by Elixir/Erlang to one used by Rust.

  The returning string format is the following:

    "nif-NIF_VERSION-ARCHITECTURE-VENDOR-OS-ABI"

  ## Examples

      iex> target()
      {:ok, "nif-2.16-x86_64-unknown-linux-gnu"} 

      iex> target()
      {:ok, "nif-2.15-aarch64-apple-darwin"}

  """
  def target(config \\ target_config()) do
    arch_os =
      case config.os_type do
        {:unix, _} ->
          config.target_system
          |> normalize_arch_os()
          |> system_arch_to_string()

        {:win32, _} ->
          existing_target =
            config.target_system
            |> system_arch_to_string()

          # For when someone is setting "TARGET_*" vars on Windows
          if existing_target in @available_targets do
            existing_target
          else
            # 32 or 64 bits
            arch =
              case config.word_size do
                4 -> "i686"
                8 -> "x86_64"
                _ -> "unknown"
              end

            config.target_system
            |> Map.put_new(:arch, arch)
            |> Map.put_new(:vendor, "pc")
            |> Map.put_new(:os, "windows")
            |> Map.put_new(:abi, "msvc")
            |> system_arch_to_string()
          end
      end

    cond do
      arch_os not in @available_targets ->
        {:error,
         "precompiled NIF is not available for this target: #{inspect(arch_os)}.\nThe available targets are:\n - #{Enum.join(@available_targets, "\n - ")}"}

      config.nif_version not in @available_nif_versions ->
        {:error,
         "precompiled NIF is not available for this NIF version: #{inspect(config.nif_version)}.\nThe available NIF versions are:\n - #{Enum.join(@available_nif_versions, "\n - ")}"}

      true ->
        {:ok, "nif-#{config.nif_version}-#{arch_os}"}
    end
  end

  defp target_config do
    current_nif_version = :erlang.system_info(:nif_version) |> List.to_string()

    nif_version =
      case find_compatible_nif_version(current_nif_version, @available_nif_versions) do
        {:ok, vsn} ->
          vsn

        :error ->
          # In case of error, use the current so we can tell the user.
          current_nif_version
      end

    current_system_arch = system_arch()

    %{
      os_type: :os.type(),
      target_system: maybe_override_with_env_vars(current_system_arch),
      word_size: :erlang.system_info(:wordsize),
      nif_version: nif_version
    }
  end

  # In case one is using this lib in a newer OTP version, we try to
  # find the latest compatible NIF version.
  def find_compatible_nif_version(vsn, available) do
    if vsn in available do
      {:ok, vsn}
    else
      [major, minor | _] = parse_version(vsn)

      available
      |> Enum.map(&parse_version/1)
      |> Enum.filter(fn
        [^major, available_minor | _] when available_minor <= minor -> true
        [_ | _] -> false
      end)
      |> case do
        [] -> :error
        match -> {:ok, match |> Enum.max() |> Enum.join(".")}
      end
    end
  end

  defp parse_version(vsn) do
    vsn |> String.split(".") |> Enum.map(&String.to_integer/1)
  end

  # Returns a map with `:arch`, `:vendor`, `:os` and maybe `:abi`.
  defp system_arch do
    base =
      :erlang.system_info(:system_architecture)
      |> List.to_string()
      |> String.split("-")

    triple_keys =
      case length(base) do
        4 ->
          [:arch, :vendor, :os, :abi]

        3 ->
          [:arch, :vendor, :os]

        _ ->
          # It's too complicated to find out, and we won't support this for now.
          []
      end

    triple_keys
    |> Enum.zip(base)
    |> Enum.into(%{})
  end

  # The idea is to support systems like Nerves.
  # See: https://hexdocs.pm/nerves/compiling-non-beam-code.html#target-cpu-arch-os-and-abi
  def maybe_override_with_env_vars(original_sys_arch, get_env \\ &System.get_env/1) do
    envs_with_keys = [
      arch: "TARGET_ARCH",
      vendor: "TARGET_VENDOR",
      os: "TARGET_OS",
      abi: "TARGET_ABI"
    ]

    updated_system_arch =
      Enum.reduce(envs_with_keys, original_sys_arch, fn {key, env_key}, acc ->
        if env_value = get_env.(env_key) do
          Map.put(acc, key, env_value)
        else
          acc
        end
      end)

    # Only replace vendor if remains the same but some other env changed the config.
    if original_sys_arch != updated_system_arch and
         original_sys_arch.vendor == updated_system_arch.vendor do
      Map.put(updated_system_arch, :vendor, "unknown")
    else
      updated_system_arch
    end
  end

  defp normalize_arch_os(target_system) do
    cond do
      target_system.os =~ "darwin" ->
        arch = with "arm" <- target_system.arch, do: "aarch64"

        %{target_system | arch: arch, os: "darwin"}

      target_system.os =~ "linux" ->
        arch = with "amd64" <- target_system.arch, do: "x86_64"
        vendor = with "pc" <- target_system.vendor, do: "unknown"

        %{target_system | arch: arch, vendor: vendor}

      true ->
        target_system
    end
  end

  defp system_arch_to_string(system_arch) do
    values =
      for key <- [:arch, :vendor, :os, :abi],
          value = system_arch[key],
          do: value

    Enum.join(values, "-")
  end

  @doc """
  Perform the download or load of the precompiled NIF

  It will look in the "priv/native/otp_app" first, and if
  that file doesn't exist, it will try to fetch from cache.
  In case there is no valid cached file, then it will try
  to download the NIF from the provided base URL.
  """
  def download_or_reuse_nif_file(rustler_opts, opts) do
    name = Keyword.fetch!(rustler_opts, :otp_app)
    version = Keyword.fetch!(opts, :version)

    native_dir = Application.app_dir(name, @native_dir)

    cache_dir = cache_dir("precompiled_nifs")

    with {:ok, target} <- target() do
      basename = rustler_opts[:crate] || name
      lib_name = "#{lib_prefix(target)}#{basename}-v#{version}-#{target}"

      file_name = lib_name_with_ext(target, lib_name)
      cached_tar_gz = Path.join(cache_dir, "#{file_name}.tar.gz")

      lib_file = Path.join(native_dir, file_name)

      base_url = Keyword.fetch!(opts, :base_url)
      # TODO: once we move to Rustler, we probably don't need to fetch `:nif_module`
      nif_module = Keyword.fetch!(opts, :nif_module) |> inspect()

      metadata = %{
        otp_app: name,
        crate: rustler_opts[:crate],
        cached_tar_gz: cached_tar_gz,
        base_url: base_url,
        basename: basename,
        lib_name: lib_name,
        file_name: file_name,
        target: target,
        version: version
      }

      write_metadata(%{nif_module => metadata})

      # Override Rustler opts so we load from the downloaded file.
      # See: https://hexdocs.pm/rustler/Rustler.html#module-configuration-options 
      new_opts =
        rustler_opts
        |> Keyword.put(:skip_compilation?, true)
        |> Keyword.put(:load_from, {name, "priv/native/#{lib_name}"})

      # TODO: add option to only write metadata
      cond do
        File.exists?(cached_tar_gz) ->
          # Remove existing NIF file so we don't have processes using it.
          # See: https://github.com/rusterlium/rustler/blob/46494d261cbedd3c798f584459e42ab7ee6ea1f4/rustler_mix/lib/rustler/compiler.ex#L134
          File.rm(lib_file)

          with :ok <- check_file_integrity(cached_tar_gz, nif_module, name),
               :ok <- :erl_tar.extract(cached_tar_gz, [:compressed, cwd: Path.dirname(lib_file)]) do
            Logger.debug("Copying NIF from cache and extracting to #{lib_file}")
            {:ok, new_opts}
          end

        true ->
          dirname = Path.dirname(lib_file)

          with :ok <- File.mkdir_p(cache_dir),
               :ok <- File.mkdir_p(dirname),
               {:ok, tar_gz} <- download_tar_gz(base_url, lib_name, cached_tar_gz),
               :ok <- File.write(cached_tar_gz, tar_gz),
               :ok <- check_file_integrity(cached_tar_gz, nif_module, name),
               :ok <-
                 :erl_tar.extract({:binary, tar_gz}, [:compressed, cwd: Path.dirname(lib_file)]) do
            Logger.debug("NIF cached at #{cached_tar_gz} and extracted to #{lib_file}")
            {:ok, new_opts}
          end
      end
    end
  end

  # TODO: consider testing this function
  defp check_file_integrity(file_path, module_name, otp_app) do
    checksum = read_map_from_file_safely(checksum_file(module_name, otp_app))
    basename = Path.basename(file_path)

    case Map.fetch(checksum, basename) do
      {:ok, algo_with_hash} ->
        [algo, hash] = String.split(algo_with_hash, ":")
        algo = String.to_existing_atom(algo)

        if algo in @checksum_algorithms do
          with {:ok, content} <- File.read(file_path) do
            tar_gz_hash =
              :crypto.hash(algo, content)
              |> Base.encode16(case: :lower)

            if hash == tar_gz_hash do
              :ok
            else
              {:error, "the integrity check failed because the checksum of files does not match"}
            end
          end
        else
          {:error,
           "checksum algorithm is not supported: #{inspect(algo)}. The supported ones are:\n - #{Enum.join(@checksum_algorithms, "\n - ")}"}
        end

      :error ->
        {:error,
         "the precompiled NIF file does not exist in the checksum file. Please consider run: `mix rustler.download #{module_name} --only-target` to generate the checksum file."}
    end
  end

  defp cache_dir(sub_dir) do
    cache_opts = if System.get_env("MIX_XDG"), do: %{os: :linux}, else: %{}
    :filename.basedir(:user_cache, Path.join("rustler", sub_dir), cache_opts)
  end

  defp lib_prefix(target) do
    if String.contains?(target, "windows") do
      ""
    else
      "lib"
    end
  end

  defp lib_name_with_ext(target, lib_name) do
    ext =
      if String.contains?(target, "windows") do
        "dll"
      else
        "so"
      end

    "#{lib_name}.#{ext}"
  end

  defp tar_gz_file_url(base_url, file_name) do
    uri = URI.parse(base_url)

    uri =
      Map.update!(uri, :path, fn path ->
        Path.join(path, "#{file_name}.tar.gz")
      end)

    to_string(uri)
  end

  defp download_tar_gz(base_url, lib_name, target_name) do
    base_url
    |> tar_gz_file_url(lib_name_with_ext(target_name, lib_name))
    |> download_nif_artifact()
  end

  defp download_nif_artifact(url) do
    url = String.to_charlist(url)
    Logger.debug("Downloading NIF from #{url}")

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = System.get_env("HTTP_PROXY") || System.get_env("http_proxy") do
      Logger.debug("Using HTTP_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)

      :httpc.set_options([{:proxy, {{String.to_charlist(host), port}, []}}])
    end

    if proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy") do
      Logger.debug("Using HTTPS_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:https_proxy, {{String.to_charlist(host), port}, []}}])
    end

    # https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
    cacertfile = CAStore.file_path() |> String.to_charlist()

    http_options = [
      ssl: [
        verify: :verify_peer,
        cacertfile: cacertfile,
        depth: 2,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    options = [body_format: :binary]

    case :httpc.request(:get, {url, []}, http_options, options) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}

      other ->
        {:error, "couldn't fetch NIF from #{url}: #{inspect(other)}"}
    end
  end

  @doc """
  Download a list of files from URLs and calculate its checksum.

  Returns a list with details of the download and the checksum of each file.
  """
  def download_nif_artifacts_with_checksums!(urls) do
    tasks =
      for url <- urls do
        Task.async(fn ->
          {:download, {url, download_nif_artifact(url)}}
        end)
      end

    cache_dir = cache_dir("precompiled_nifs")
    :ok = File.mkdir_p(cache_dir)

    # TODO: consider using `Task.yield_many` with a custom timeout
    Enum.map(tasks, fn task ->
      with {:download, {url, download_result}} <- Task.await(task),
           {:download_result, {:ok, body}} <- {:download_result, download_result},
           hash <- :crypto.hash(@checksum_algo, body),
           path <- Path.join(cache_dir, basename_from_url(url)),
           {:file, :ok} <- {:file, File.write(path, body)} do
        checksum = Base.encode16(hash, case: :lower)

        Logger.debug(
          "NIF cached at #{path} with checksum #{inspect(checksum)} (#{@checksum_algo})"
        )

        %{
          url: url,
          path: path,
          checksum: checksum,
          checksum_algo: @checksum_algo
        }
      else
        {context, result} ->
          raise "could not finish the download of NIF artifacts. Context: #{inspect(context)}. Reason: #{inspect(result)}"
      end
    end)
  end

  defp basename_from_url(url) do
    uri = URI.parse(url)

    uri.path
    |> String.split("/")
    |> List.last()
  end

  defp read_map_from_file_safely(file) do
    opts = [file: file, warn_on_unnecessary_quotes: false]

    with {:ok, contents} <- File.read(file),
         {:ok, quoted} <- Code.string_to_quoted(contents, opts),
         {%{} = contents, _binding} <- Code.eval_quoted(quoted, [], opts) do
      contents
    else
      _ -> %{}
    end
  end

  # TODO: consider acquiring a lock for that file maybe with another tmp file.
  defp write_metadata(metadata) do
    existing = read_map_from_file_safely(metadata_file())

    unless Map.equal?(metadata, existing) do
      file = metadata_file()
      dir = Path.dirname(file)
      :ok = File.mkdir_p(dir)

      map = Map.merge(existing, metadata)

      lines =
        for {nif_module, details} <- Enum.sort(map), details != nil do
          ~s(  "#{nif_module}" => #{inspect(details, limit: :infinity)},\n)
        end

      File.write!(file, ["%{\n", lines, "}\n"])
    end

    :ok
  end

  defp metadata_file do
    rustler_cache = cache_dir("metadata")
    Path.join(rustler_cache, "nif_modules.exs")
  end

  @doc """
  Write the checksum file with all NIFs available.

  It receives the module name and checksums.
  """
  def write_checksum!(module_name, checksums) do
    metadata = read_map_from_file_safely(metadata_file())

    case metadata[module_name] do
      %{otp_app: name} ->
        file = checksum_file(module_name, name)
        dir = Path.dirname(file)
        :ok = File.mkdir_p(dir)

        pairs =
          for %{path: path, checksum: checksum, checksum_algo: algo} <- checksums, into: %{} do
            basename = Path.basename(path)
            checksum = "#{algo}:#{checksum}"
            {basename, checksum}
          end

        lines =
          for {filename, checksum} <- Enum.sort(pairs) do
            ~s(  "#{filename}" => #{inspect(checksum, limit: :infinity)},\n)
          end

        File.write!(file, ["%{\n", lines, "}\n"])

      _ ->
        raise "could not find the OTP app for #{inspect(module_name)} in the metadata file. Please compile the project again with: `mix compile --force`."
    end
  end

  # The checksum file is saved in the "priv/native" of the OTP app.
  # The "phash2" of the module name is used as sufix for the file name.
  defp checksum_file(module_name, otp_app) do
    native_dir = Application.app_dir(otp_app, @native_dir)

    module_id =
      module_name
      |> :erlang.phash2()
      |> Integer.to_string()
      |> Base.encode16(case: :lower)

    Path.join(native_dir, "checksum-#{module_id}.exs")
  end
end
