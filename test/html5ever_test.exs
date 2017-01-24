defmodule Html5everTest do
  use ExUnit.Case
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

  test "parse example.com html" do
    html = read_html("example.html")
    assert match?({:ok, _}, Html5ever.parse(html))
  end

  test "parse drudgereport.com html" do
    html = read_html("drudgereport.html")
    assert match?({:ok, _}, Html5ever.parse(html))
  end

  test "unbalanced worst case" do
    html = String.duplicate("<div>", 100)
    assert match?({:ok, _}, Html5ever.parse(html))
  end

end
