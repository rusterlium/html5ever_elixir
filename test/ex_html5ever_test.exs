defmodule ExHtml5everTest do
  use ExUnit.Case
  doctest ExHtml5ever

  #def p() do
  #  receive do
  #    thing -> IO.inspect thing
  #  end
  #  p()
  #end

  #setup_all do
  #  pid = Process.spawn(ExHtml5everTest, :p, [], [])
  #  :erlang.system_monitor(pid, [{:long_schedule, 1}])
  #  :ok
  #end

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
    html = read_html("example.html")
    assert match?({:ok, _}, ExHtml5ever.parse(html))
  end

  test "parse drudgereport.com html" do
    html = read_html("drudgereport.html")
    assert match?({:ok, _}, ExHtml5ever.parse(html))
  end

  test "unbalanced worst case" do
    html = String.duplicate("<div>", 100)
    assert match?({:ok, _}, ExHtml5ever.parse(html))
  end

end
