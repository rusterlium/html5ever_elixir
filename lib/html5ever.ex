defmodule Html5ever do
  @moduledoc """
  The html5ever is an HTML parser written in Rust.
  """

  @doc """
  Parses an HTML document from a string.

  This returns a list of tuples representing the HTML tree.

  ## Example

      iex> Html5ever.parse("<!doctype html><html><body><h1>Hello world</h1></body></html>")
      {:ok,
       [
         {:doctype, "html", "", ""},
         {"html", [], [{"head", [], []}, {"body", [], [{"h1", [], ["Hello world"]}]}]}
       ]}

  """
  def parse(html) when byte_size(html) > 500 do
    parse_async(html)
  end

  def parse(html) do
    parse_sync(html)
  end

  @doc """
  Parses an HTML document from a string and returns a map.

  The map contains the document structure.

  ## Example

      iex> Html5ever.flat_parse("<!doctype html><html><body><h1>Hello world</h1></body></html>")
      {:ok,
       %{
         nodes: %{
           0 => %{id: 0, parent: nil, type: :document},
           1 => %{id: 1, parent: 0, type: :doctype},
           2 => %{
             attrs: [],
             children: [3, 4],
             id: 2,
             name: "html",
             parent: 0,
             type: :element
           },
           3 => %{
             attrs: [],
             children: [],
             id: 3,
             name: "head",
             parent: 2,
             type: :element
           },
           4 => %{
             attrs: [],
             children: [5],
             id: 4,
             name: "body",
             parent: 2,
             type: :element
           },
           5 => %{
             attrs: [],
             children: [6],
             id: 5,
             name: "h1",
             parent: 4,
             type: :element
           },
           6 => %{contents: "Hello world", id: 6, parent: 5, type: :text}
         },
         root: 0
       }}

  """
  def flat_parse(html) when byte_size(html) > 500 do
    flat_parse_async(html)
  end

  def flat_parse(html) do
    flat_parse_sync(html)
  end

  defp parse_sync(html) do
    case Html5ever.Native.parse_sync(html) do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}

      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end

  defp parse_async(html) do
    :ok = Html5ever.Native.parse_async(html)

    receive do
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
    :ok = Html5ever.Native.flat_parse_async(html)

    receive do
      {:html5ever_nif_result, :ok, result} ->
        {:ok, result}

      {:html5ever_nif_result, :error, err} ->
        {:error, err}
    end
  end
end
