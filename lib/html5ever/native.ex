defmodule NifNotLoadedError do
  defexception message: "nif not loaded"
end

defmodule Html5ever.Native do
  use Rustler, otp_app: :html5ever, crate: "html5ever_nif"

  def parse_async(_binary), do: err()
  def parse_sync(_binary), do: err()

  defp err() do
    throw NifNotLoadedError
  end
end
