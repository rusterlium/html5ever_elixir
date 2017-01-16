defmodule ExHtml5ever do
  @moduledoc """
  Documentation for ExHtml5ever.
  """

  def parse(html) when byte_size(html) > 500 do
    parse_async(html)
  end
  def parse(html) do
    parse_sync(html)
  end

  defp parse_async(html) do
    ExHtml5ever.Native.parse_async(html)
    receive do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}
      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end

  defp parse_sync(html) do
    case ExHtml5ever.Native.parse_sync(html) do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}
      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end

end
