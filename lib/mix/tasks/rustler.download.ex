defmodule Mix.Tasks.Rustler.Download do
  @shortdoc "Download precompiled NIFs and build checksums"

  use Mix.Task

  @impl true
  def run(_) do
    IO.puts(inspect(Html5ever.Precompiled.available_targets()))
  end
end
