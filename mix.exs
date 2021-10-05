defmodule Html5ever.Mixfile do
  use Mix.Project

  @version "0.9.0"
  @repo_url "https://github.com/rusterlium/html5ever_elixir"

  def project do
    [
      app: :html5ever,
      version: @version,
      elixir: "~> 1.4",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps(),
      docs: docs(),
      description: "NIF binding of html5ever using Rustler",
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:rustler, "~> 0.22.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      main: "Html5ever",
      source_ref: "v#{@version}",
      source_url: @repo_url
    ]
  end

  defp package do
    [
      files: ["lib", "native", "mix.exs", "README.md", "LICENSE-APACHE", "LICENSE-MIT"],
      maintainers: ["hansihe", "philip"],
      licenses: ["MIT", "Apache-2.0"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
