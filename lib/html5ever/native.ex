defmodule Html5ever.Native do
  @moduledoc false
  require Logger

  mix_config = Mix.Project.config()
  @version mix_config[:version]
  # @github_url mix_config[:package][:links]["GitHub"]

  rustler_opts = [otp_app: :html5ever, crate: "html5ever_nif", mode: :release]

  opts =
    if System.get_env("HTML5EVER_BUILD") in ["1", "true"] do
      rustler_opts
    else
      case Html5ever.Precompiled.download_or_reuse_nif_file(
             rustler_opts,
             # TODO: change to the following before merging PR
             # base_url: "#{@github_url}/releases/download/v#{@version}",
             base_url:
               "https://github.com/philss/html5ever_elixir/releases/download/testing-release33",
             version: @version
           ) do
        {:ok, new_opts} ->
          new_opts

        {:error, error} ->
          error =
            "Error while downloading precompiled NIF: #{error}. Set HTML5EVER_BUILD=1 to compile the NIF from scratch"

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
  def parse_async(_binary), do: err()
  def flat_parse_sync(_binary), do: err()
  def flat_parse_async(_binary), do: err()

  defp err, do: :erlang.nif_error(:nif_not_loaded)
end
