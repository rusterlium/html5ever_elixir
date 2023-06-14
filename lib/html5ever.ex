defmodule Html5ever do
  @moduledoc """
  This is an HTML parser written in Rust.

  The project provides a NIF - Native Implemented Function.
  It works on top of [a parser of the same name](https://github.com/servo/html5ever)
  from the Servo project.

  By default this lib will try to use a precompiled NIF
  from the GitHub releases page. This way you don't need
  to have the Rust toolchain installed.
  In case no precompiled file is found and the Mix env is
  production then an error is raised.

  You can force the compilation to occur by setting the
  value of the `HTML5EVER_BUILD` environment variable to
  "true" or "1". Alternatively you can also set the application
  env `:build_from_source` to `true` in order to force the build:

      config :html5ever, Html5ever, build_from_source: true

  This project is possible thanks to [Rustler](https://hexdocs.pm/rustler).
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
  def parse(html) when is_binary(html) do
    Html5ever.Native.parse(html, false)
  end

  @doc """
  Same as `parse/1`, but with attributes as maps.

  This is going to remove duplicated attributes, keeping the ones
  that appear first.

  ## Example

      iex> Html5ever.parse_with_attributes_as_maps(
      ...>   "<!doctype html><html><body><h1 class=title>Hello world</h1></body></html>"
      ...> )
      {:ok,
       [
         {:doctype, "html", "", ""},
         {"html", %{}, [{"head", %{}, []}, {"body", %{}, [{"h1", %{"class" => "title"}, ["Hello world"]}]}]}
       ]}

  """
  def parse_with_attributes_as_maps(html) when is_binary(html) do
    Html5ever.Native.parse(html, true)
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
  def flat_parse(html) do
    Html5ever.Native.flat_parse(html, false)
  end

  @doc """
  Same as `flat_parse/1`, but with attributes as maps.

  This is going to remove duplicated attributes, keeping the ones
  that appear first.
  """
  def flat_parse_with_attributes_as_maps(html) when is_binary(html) do
    Html5ever.Native.flat_parse(html, true)
  end
end
