defmodule Html5ever.Mixfile do
  use Mix.Project

  @version "0.13.1"
  @repo_url "https://github.com/rusterlium/html5ever_elixir"

  def project do
    [
      app: :html5ever,
      version: @version,
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: "NIF binding of html5ever using Rustler",
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger, :inets, :public_key]]
  end

  defp deps do
    [
      {:rustler_precompiled, "~> 0.4"},
      {:rustler, ">= 0.0.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      main: "Html5ever",
      extras: ["CHANGELOG.md"],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @repo_url
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "native",
        "checksum-*.exs",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE-APACHE",
        "LICENSE-MIT"
      ],
      maintainers: ["hansihe", "philip"],
      licenses: ["MIT", "Apache-2.0"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
