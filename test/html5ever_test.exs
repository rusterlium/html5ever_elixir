defmodule Html5everTest do
  use ExUnit.Case, async: true
  doctest Html5ever

  def read_html(name) do
    path = Path.join([:code.priv_dir(:html5ever), "test_data", name])
    File.read!(path)
  end

  test "parse basic html" do
    html = "<html><head></head><body><h1>Hello</h1><!-- my comment --></body></html>"

    assert Html5ever.parse(html) ==
             {:ok,
              [
                {"html", [],
                 [
                   {"head", [], []},
                   {"body", [], [{"h1", [], ["Hello"]}, {:comment, " my comment "}]}
                 ]}
              ]}
  end

  test "does not parse with not valid UTF8 binary" do
    invalid =
      <<98, 29, 104, 122, 46, 145, 14, 37, 122, 155, 227, 121, 49, 120, 108, 209, 155, 113, 229,
        98, 90, 181, 146>>

    assert Html5ever.parse(invalid) ==
             {:error, "cannot transform bytes from binary to a valid UTF8 string"}
  end

  test "flat parse basic html" do
    html = "<html><head></head><body test=\"woo\"></body></html>"

    ret =
      {:ok,
       %{
         nodes: %{
           0 => %{id: 0, parent: nil, type: :document},
           1 => %{children: [2, 3], id: 1, parent: 0, type: :element, attrs: [], name: "html"},
           2 => %{children: [], id: 2, parent: 1, type: :element, attrs: [], name: "head"},
           3 => %{
             children: [],
             id: 3,
             parent: 1,
             type: :element,
             attrs: [{"test", "woo"}],
             name: "body"
           }
         },
         root: 0
       }}

    assert Html5ever.flat_parse(html) == ret
  end

  test "does not flat parse with not valid UTF8 binary" do
    invalid =
      <<98, 29, 104, 122, 46, 145, 14, 37, 122, 155, 227, 121, 49, 120, 108, 209, 155, 113, 229,
        98, 90, 181, 146>>

    assert Html5ever.flat_parse(invalid) ==
             {:error, "cannot transform bytes from binary to a valid UTF8 string"}
  end

  test "flat parse basic html with attributes as maps" do
    # Duplicated attribute is removed.
    html = "<html><head></head><body test=\"woo\" class=\"content\" test=\"baz\"></body></html>"

    ret =
      {:ok,
       %{
         nodes: %{
           0 => %{id: 0, parent: nil, type: :document},
           1 => %{children: [2, 3], id: 1, parent: 0, type: :element, attrs: %{}, name: "html"},
           2 => %{children: [], id: 2, parent: 1, type: :element, attrs: %{}, name: "head"},
           3 => %{
             children: [],
             id: 3,
             parent: 1,
             type: :element,
             attrs: %{"test" => "woo", "class" => "content"},
             name: "body"
           }
         },
         root: 0
       }}

    assert Html5ever.flat_parse_with_attributes_as_maps(html) == ret
  end

  test "parse example.com html" do
    html = read_html("example.html")
    assert {:ok, _} = Html5ever.parse(html)
  end

  test "flat parse example.com html" do
    html = read_html("example.html")
    assert {:ok, _} = Html5ever.flat_parse(html)
  end

  test "parse drudgereport.com html" do
    html = read_html("drudgereport.html")
    assert {:ok, _} = Html5ever.parse(html)
  end

  test "flat parse drudgereport.com html" do
    html = read_html("drudgereport.html")
    assert {:ok, _} = Html5ever.flat_parse(html)
  end

  test "unbalanced worst case" do
    html = String.duplicate("<div>", 100)
    assert {:ok, _} = Html5ever.parse(html)
  end

  test "flat unbalanced worst case" do
    html = String.duplicate("<div>", 100)
    assert {:ok, _} = Html5ever.flat_parse(html)
  end

  test "reasonably deep html" do
    html = """
    <!doctype html>
    <html>
      <head>
        <title>Test</title>
      </head>
      <body>
        <div class="content">
          <span>
            <div>
              <span>
                <small>
                very deep content
                </small>
              </span>
            </div>
            <img src="file.jpg" />
          </span>
        </div>
      </body>
    </html>
    """

    parsed = Html5ever.parse(html)

    assert {:ok,
            [
              {:doctype, "html", "", ""},
              {"html", [],
               [
                 {"head", [], ["\n", "    ", {"title", [], ["Test"]}, "\n", "  "]},
                 "\n",
                 "  ",
                 {"body", [],
                  [
                    "\n",
                    "    ",
                    {"div", [{"class", "content"}],
                     [
                       "\n",
                       "      ",
                       {"span", [],
                        [
                          "\n",
                          "        ",
                          {"div", [],
                           [
                             "\n",
                             "          ",
                             {"span", [],
                              [
                                "\n",
                                "            ",
                                {"small", [],
                                 ["\n", "            very deep content", "\n", "            "]},
                                "\n",
                                "          "
                              ]},
                             "\n",
                             "        "
                           ]},
                          "\n",
                          "        ",
                          {"img", [{"src", "file.jpg"}], []},
                          "\n",
                          "      "
                        ]},
                       "\n",
                       "    "
                     ]},
                    "\n",
                    "  ",
                    "\n",
                    "\n"
                  ]}
               ]}
            ]} = parsed
  end

  test "reasonably deep html with attributes as maps" do
    html = """
    <!doctype html>
    <html>
      <head>
        <title>Test</title>
      </head>
      <body>
        <div class="content">
          <span>
            <div>
              <span>
                <small>
                very deep content
                </small>
              </span>
            </div>
            <img src="file.jpg" />
          </span>
        </div>
      </body>
    </html>
    """

    parsed = Html5ever.parse_with_attributes_as_maps(html)

    assert {:ok,
            [
              {:doctype, "html", "", ""},
              {"html", %{},
               [
                 {"head", %{}, ["\n", "    ", {"title", %{}, ["Test"]}, "\n", "  "]},
                 "\n",
                 "  ",
                 {"body", %{},
                  [
                    "\n",
                    "    ",
                    {"div", %{"class" => "content"},
                     [
                       "\n",
                       "      ",
                       {"span", %{},
                        [
                          "\n",
                          "        ",
                          {"div", %{},
                           [
                             "\n",
                             "          ",
                             {"span", %{},
                              [
                                "\n",
                                "            ",
                                {"small", %{},
                                 ["\n", "            very deep content", "\n", "            "]},
                                "\n",
                                "          "
                              ]},
                             "\n",
                             "        "
                           ]},
                          "\n",
                          "        ",
                          {"img", %{"src" => "file.jpg"}, []},
                          "\n",
                          "      "
                        ]},
                       "\n",
                       "    "
                     ]},
                    "\n",
                    "  ",
                    "\n",
                    "\n"
                  ]}
               ]}
            ]} = parsed
  end

  test "parse html with a template tag ignores template content" do
    html = """
    <!doctype html>
    <html>
    <head><title>With template</title></head>
    <body>
    <h1>Document</h1>
    <template>
      <h2>Flower</h2>
      <img src="img_white_flower.jpg" width="214" height="204">
    </template>
    </body>
    </html>
    """

    assert Html5ever.parse(html) ==
             {:ok,
              [
                {:doctype, "html", "", ""},
                {"html", [],
                 [
                   {"head", [], [{"title", [], ["With template"]}]},
                   "\n",
                   {"body", [],
                    ["\n", {"h1", [], ["Document"]}, "\n", {"template", [], []}, "\n", "\n", "\n"]}
                 ]}
              ]}
  end

  test "parse html starting with a XML tag" do
    html = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- also a comment is allowed -->
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
      <head><title>Hello</title></head>
      <body>
        <a id="anchor" href="https://example.com">link</a>
      </body>
    </html>
    """

    assert Html5ever.parse(html) ==
             {:ok,
              [
                {:comment, "?xml version=\"1.0\" encoding=\"UTF-8\"?"},
                {:comment, " also a comment is allowed "},
                {:doctype, "html", "-//W3C//DTD XHTML 1.0 Strict//EN",
                 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"},
                {
                  "html",
                  [{"xmlns", "http://www.w3.org/1999/xhtml"}, {"xml:lang", "en"}, {"lang", "en"}],
                  [
                    {"head", [], [{"title", [], ["Hello"]}]},
                    "\n",
                    "  ",
                    {"body", [],
                     [
                       "\n",
                       "    ",
                       {"a", [{"id", "anchor"}, {"href", "https://example.com"}], ["link"]},
                       "\n",
                       "  ",
                       "\n",
                       "\n"
                     ]}
                  ]
                }
              ]}
  end
end
