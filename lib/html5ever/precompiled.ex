defmodule Html5ever.Precompiled do
  @moduledoc false

  require Logger

  @available_targets ~w(
    aarch64-apple-darwin
    x86_64-apple-darwin
    x86_64-unknown-linux-gnu
    x86_64-unknown-linux-musl
    arm-unknown-linux-gnueabihf
    x86_64-pc-windows-msvc
    x86_64-pc-windows-gnu
  )
  @available_nif_versions ~w(2.14 2.15 2.16)

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
    sys_arch = maybe_override_with_env_vars(config.system_arch)

    arch_os =
      case config.os_type do
        {:unix, os} ->
          os
          |> normalize_arch_os(sys_arch)
          |> system_arch_to_string()

        {:win32, _} ->
          # 32 or 64 bits
          arch =
            case config.word_size do
              4 -> "i686"
              8 -> "x86_64"
              _ -> "unknown"
            end

          sys_arch
          |> Map.put_new(:arch, arch)
          |> Map.put_new(:vendor, "pc")
          |> Map.put_new(:os, "windows")
          |> Map.put_new(:abi, "msvc")
          |> system_arch_to_string()
      end

    cond do
      arch_os not in @available_targets ->
        {:error,
         "precompiled NIF is not available for this target: #{inspect(arch_os)}. The available targets are:\n - #{Enum.join(@available_targets, "\n - ")}"}

      config.nif_version not in @available_nif_versions ->
        {:error,
         "precompiled NIF is not available for this NIF version: #{inspect(config.nif_version)}. The available NIF versions are:\n - #{Enum.join(@available_nif_versions, "\n - ")}"}

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

    %{
      os_type: :os.type(),
      system_arch: system_arch(),
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
  defp maybe_override_with_env_vars(system_arch) do
    envs_with_keys = [arch: "TARGET_ARCH", os: "TARGET_OS", abi: "TARGET_ABI"]

    Enum.reduce(envs_with_keys, system_arch, fn {key, env_key}, acc ->
      if env_value = System.get_env(env_key) do
        Map.put(acc, key, env_value)
      else
        acc
      end
    end)
  end

  defp normalize_arch_os(:darwin, sys_arch) do
    arch = with "arm" <- sys_arch.arch, do: "aarch64"

    %{sys_arch | arch: arch, os: "darwin"}
  end

  defp normalize_arch_os(:linux, sys_arch) do
    arch = with "amd64" <- sys_arch.arch, do: "x86_64"
    vendor = with "pc" <- sys_arch.vendor, do: "unknown"

    # Fix vendor for Nerves
    vendor =
      if arch == "arm" and vendor == "buildroot" do
        "unknown"
      else
        vendor
      end

    %{sys_arch | arch: arch, vendor: vendor}
  end

  defp normalize_arch_os(_other, sys_arch), do: sys_arch

  defp system_arch_to_string(system_arch) do
    values =
      for key <- [:arch, :vendor, :os, :abi],
          value = system_arch[key],
          do: value

    Enum.join(values, "-")
  end

  def download_or_reuse_nif_file(rustler_opts, opts) do
    name = Keyword.fetch!(rustler_opts, :otp_app)
    version = Keyword.fetch!(opts, :version)

    priv_dir = Application.app_dir(name, "priv")

    cache_opts = if System.get_env("MIX_XDG"), do: %{os: :linux}, else: %{}
    cache_dir = :filename.basedir(:user_cache, Atom.to_string(name), cache_opts)

    with {:ok, target} <- target() do
      nif_name = rustler_opts[:crate] || name
      lib_name = "#{lib_prefix(target)}#{nif_name}-v#{version}-#{target}"

      file_name = lib_name_with_ext(target, lib_name)
      cached_tar_gz = Path.join(cache_dir, "#{file_name}.tar.gz")

      lib_file =
        priv_dir
        |> Path.join("native")
        |> Path.join(file_name)

      # Override Rustler opts so we load from the downloaded file.
      # See: https://hexdocs.pm/rustler/Rustler.html#module-configuration-options 
      new_opts =
        rustler_opts
        |> Keyword.put(:skip_compilation?, true)
        |> Keyword.put(:load_from, {name, "priv/native/#{lib_name}"})

      cond do
        File.exists?(lib_file) ->
          Logger.debug("Using NIF from #{lib_file}")
          {:ok, new_opts}

        File.exists?(cached_tar_gz) ->
          with :ok <- :erl_tar.extract(cached_tar_gz, [:compressed, cwd: Path.dirname(lib_file)]) do
            Logger.debug("Copying NIF from cache and extracting to #{lib_file}")
            {:ok, new_opts}
          end

        true ->
          base_url = Keyword.fetch!(opts, :base_url)
          dirname = Path.dirname(lib_file)

          with :ok <- File.mkdir_p(cache_dir),
               :ok <- File.mkdir_p(dirname),
               {:ok, tar_gz} <- download_tar_gz(base_url, lib_name, cached_tar_gz),
               :ok <-
                 :erl_tar.extract({:binary, tar_gz}, [:compressed, cwd: Path.dirname(lib_file)]) do
            Logger.debug("NIF cached at #{cached_tar_gz} and extracted to #{lib_file}")
            {:ok, new_opts}
          end
      end
    end
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

  defp download_tar_gz(base_url, lib_name, target_name) do
    uri = URI.parse(base_url)

    uri =
      Map.update!(uri, :path, fn path ->
        "#{path}/#{lib_name_with_ext(target_name, lib_name)}.tar.gz"
      end)

    download_nif_artifact(to_string(uri))
  end

  # Gets the NIF file from a given URL.
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
end
