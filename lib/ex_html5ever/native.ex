defmodule NifNotLoadedError do
  defexception message: "nif not loaded"
end

defmodule ExHtml5ever.Native do
  use Rustler, otp_app: :ex_html5ever, crate: "html5ever_nif"

  def parse_async(binary), do: err()

  defp err() do
    throw NifNotLoadedError
  end

end
