defmodule ExHtml5ever.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_html5ever,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     compilers: [:rustler] ++ Mix.compilers(),
     rustler_crates: rustler_crates(),
     deps: deps()]
  end

  def rustler_crates do
    [
      html5ever_nif: [
        path: "native/html5ever_nif",
        cargo: :system,
        default_features: false,
        features: [],
        mode: :release,#(if Mix.env == :prod, do: :release, else: :debug),
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:rustler, github: "hansihe/Rustler", sparse: "rustler_mix"}]
  end
end
