defmodule NifNotLoadedError do
  defexception message: "nif not loaded"
end

defmodule ExHtml5ever.Native do
  @on_load :load_nif

  def load_nif do
    require Rustler
    Rustler.load_nif(:ex_html5ever, "html5ever_nif")
  end

  def parse_async(binary), do: err()

  defp err() do
    throw NifNotLoadedError
  end

end
