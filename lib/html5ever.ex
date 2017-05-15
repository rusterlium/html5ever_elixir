defmodule Html5ever do
  @moduledoc """
  Documentation for ExHtml5ever.
  """

  def parse(html) when byte_size(html) > 500 do
    parse_async(html)
  end
  def parse(html) do
    parse_sync(html)
  end

  def flat_parse(html) when byte_size(html) > 500 do
    flat_parse_async(html)
  end
  def flat_parse(html) do
    flat_parse_sync(html)
  end

  defp parse_async(html) do
    Html5ever.Native.parse_async(html)
    receive do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}
      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end

  defp parse_sync(html) do
    case Html5ever.Native.parse_sync(html) do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}
      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end

  defp flat_parse_sync(html) do
    case Html5ever.Native.flat_parse_sync(html) do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}
      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end

  defp flat_parse_async(html) do
    case Html5ever.Native.flat_parse_sync(html) do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}
      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end

end
