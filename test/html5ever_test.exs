defmodule Html5everTest do
  use ExUnit.Case, async: true
  doctest Html5ever

  def read_html(name) do
    dir = to_string(:code.priv_dir(:html5ever)) <> "/test_data/"
    File.read!(dir <> name)
  end

  test "parse basic html" do
    html = "<html><head></head><body></body></html>"
    ret = {:ok, [{"html", [], [{"head", [], []}, {"body", [], []}]}]}
    assert Html5ever.parse(html) == ret
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
end
