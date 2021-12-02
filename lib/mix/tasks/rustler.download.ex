defmodule Mix.Tasks.Rustler.Download do
  @shortdoc "Download precompiled NIFs and build checksums"

  @moduledoc """
  This is responsible for downloading the precompiled NIFs for a given module.

  This task must only be used by Rustler's package creators who want to ship
  precompiled NIFs. The goal is to download precompiled packages and
  generate a checksum to check-in alongside the Hex repository. This is done
  by passing the `--all` flag.

  You can also use the `--only-local` flag to download only the precompiled
  package for use during development.
  """

  use Mix.Task

  alias Html5ever.Precompiled

  @impl true
  def run([module_name | maybe_flags]) do
    urls =
      case maybe_flags do
        ["--all"] ->
          Precompiled.available_nif_urls(module_name)

        ["--only-local"] ->
          [Precompiled.current_target_nif_url(module_name)]

        [] ->
          raise "you need to specify either \"--all\" or \"--only-local\" flags"
      end

    result = Precompiled.download_nif_artifacts_with_checksums!(urls)
    Precompiled.write_checksum!(module_name, result)
  end

  @impl true
  def run([]) do
    raise "the module name and a flag is expected. Use \"--all\" or \"--only-local\" flags"
  end
end
