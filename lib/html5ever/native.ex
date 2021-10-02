defmodule Html5ever.Native do
  use Rustler, otp_app: :html5ever, crate: "html5ever_nif", mode: :release

  def parse_sync(_binary), do: err()
  def parse_async(_binary), do: err()
  def flat_parse_sync(_binary), do: err()
  def flat_parse_async(_binary), do: err()

  defp err, do: :erlang.nif_error(:nif_not_loaded)
end
