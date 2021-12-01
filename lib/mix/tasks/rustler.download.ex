defmodule Mix.Tasks.Rustler.Download do
  @shortdoc "Download precompiled NIFs and build checksums"

  @moduledoc """
  This is responsible for downloading the precompiled NIFs for a given module.

  It will also save the checksum file in the proper location in case it is not
  present. This is important because we need to calculate the checksum before
  extracting the NIF to the proper location.
  """

  use Mix.Task

  alias Html5ever.Precompiled

  @impl true
  def run([module_name | maybe_flags]) do
    urls =
      case maybe_flags do
        ["--all"] ->
          Precompiled.available_nif_urls(module_name)

        ["--only-target"] ->
          [Precompiled.current_target_nif_url(module_name)]

        [] ->
          raise "you need to specify either \"--all\" or \"--only-target\" flags"
      end

    result = Precompiled.download_nif_artifacts_with_checksums!(urls)
    Precompiled.write_checksum!(module_name, result)
  end

  @impl true
  def run([]) do
    raise "the module name and a flag is expected. Use \"--all\" or \"--only-target\" flags"
  end
end
