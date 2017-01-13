defmodule ExHtml5everTest do
  use ExUnit.Case
  doctest ExHtml5ever

  def read_html(name) do
    dir = to_string(:code.priv_dir(:ex_html5ever)) <> "/test_data/"
    File.read!(dir <> name)
  end

  test "parse basic html" do
    html = "<html><head></head><body></body></html>"
    ret = {:ok, [{"html", [], [{"head", [], []}, {"body", [], []}]}]}
    assert ExHtml5ever.parse(html) == ret
  end

  test "parse example.com html" do
    html = read_html("drudgereport.html")
    assert match?({:ok, _}, ExHtml5ever.parse(html))
  end

  test "parse drudgereport.com html" do
    html = read_html("drudgereport.html")
    assert match?({:ok, _}, ExHtml5ever.parse(html))
  end

end
