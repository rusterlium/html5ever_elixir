defmodule Html5ever.Native do
  @moduledoc false
  require Logger

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links]["GitHub"]

  rustler_opts = [otp_app: :html5ever, crate: "html5ever_nif", mode: :release]
  env_config = Application.get_env(rustler_opts[:otp_app], Html5ever, [])

  opts =
    if System.get_env("HTML5EVER_BUILD") in ["1", "true"] or env_config[:build_from_source] do
      rustler_opts
    else
      case Html5ever.Precompiled.download_or_reuse_nif_file(
             rustler_opts,
             base_url: "#{github_url}/releases/download/v#{version}",
             version: version
           ) do
        {:ok, new_opts} ->
          new_opts

        {:error, error} ->
          error =
            "Error while downloading precompiled NIF: #{error}\n\nSet HTML5EVER_BUILD=1 env var to compile the NIF from scratch. You can also configure this application to force compilation:\n\n    config :html5ever, Html5ever, build_from_source: true\n"

          if Mix.env() == :prod do
            raise error
          else
            Logger.debug(error)
            rustler_opts
          end
      end
    end

  # This module will be replaced by the NIF module after
  # loaded. It throws an error in case the NIF can't be loaded.
  use Rustler, opts

  def parse_sync(_binary), do: err()
  def parse_dirty(_binary), do: err()
  def flat_parse_sync(_binary), do: err()
  def flat_parse_dirty(_binary), do: err()

  defp err, do: :erlang.nif_error(:nif_not_loaded)
end
