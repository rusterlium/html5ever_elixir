defmodule ExHtml5ever do
  @moduledoc """
  Documentation for ExHtml5ever.
  """

  def parse(html) do
    ExHtml5ever.Native.parse_async(html)
    receive do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}
      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end

end
