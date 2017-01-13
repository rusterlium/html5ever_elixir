defmodule ExHtml5everTest do
  use ExUnit.Case
  doctest ExHtml5ever

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "parse basic html" do
    html = "<html><head></head><body></body></html>"
    ret = {:ok, [{"html", [], [{"head", [], []}, {"body", [], []}]}]}
    assert ExHtml5ever.parse(html) == ret
  end

  test "parse dailymail html" do
    test_data_dir = to_string(:code.priv_dir(:ex_html5ever)) <> "/test_data/"
    html = File.read!(test_data_dir <> "dailymail.html")
    assert match?({:ok, _}, ExHtml5ever.parse(html))
  end

end
