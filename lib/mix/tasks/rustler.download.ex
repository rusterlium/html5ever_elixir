defmodule Mix.Tasks.Rustler.Download do
  @shortdoc "Download precompiled NIFs and build checksums"

  use Mix.Task

  # mix rustler.download Html5Ever --all 
  # or
  # mix rustler.download Html5Ever

  @impl true
  def run(_) do
    urls = Html5ever.Precompiled.available_nif_urls("Html5ever.Native")
    IO.puts(inspect(urls))

    result = Html5ever.Precompiled.download_nif_artifacts_with_checksums(urls)

    IO.inspect(result, label: "checksums")
    # TODO: save result in "priv/native" of the otp app (get from metadata)
  end
end
