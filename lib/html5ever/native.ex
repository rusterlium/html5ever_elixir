defmodule Html5ever.Native do
  @moduledoc false

  # This module will be replaced by the NIF module after
  # loaded. It throws an error in case the NIF can't be loaded.
  use Rustler, otp_app: :html5ever, crate: "html5ever_nif", mode: :release

  def parse_sync(_binary), do: err()
  def parse_async(_binary), do: err()
  def flat_parse_sync(_binary), do: err()
  def flat_parse_async(_binary), do: err()

  defp err, do: :erlang.nif_error(:nif_not_loaded)
end
