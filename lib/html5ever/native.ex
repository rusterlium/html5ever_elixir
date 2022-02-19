defmodule Html5ever.Native do
  @moduledoc false
  require Logger

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links]["GitHub"]

  env_config = Application.get_env(:html5ever, Html5ever, [])

  # This module will be replaced by the NIF module after
  # loaded. It throws an error in case the NIF can't be loaded.
  use RustlerPrecompiled,
    otp_app: :html5ever,
    crate: "html5ever_nif",
    mode: :release,
    base_url: "#{github_url}/releases/download/v#{version}",
    force_build:
      System.get_env("HTML5EVER_BUILD") in ["1", "true"] or env_config[:build_from_source],
    version: version

  def parse_sync(_binary), do: err()
  def parse_dirty(_binary), do: err()
  def flat_parse_sync(_binary), do: err()
  def flat_parse_dirty(_binary), do: err()

  defp err, do: :erlang.nif_error(:nif_not_loaded)
end
