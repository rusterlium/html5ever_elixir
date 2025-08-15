# Html5ever binding for Elixir

[![CI](https://github.com/rusterlium/html5ever_elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/rusterlium/html5ever_elixir/actions/workflows/ci.yml)

NIF binding of [html5ever](https://github.com/servo/html5ever) using [Rustler](https://github.com/rusterlium/rustler).

It is currently functional with basic features.

## Installation

The package can be installed by adding `html5ever` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:html5ever, "~> 0.17.0"}]
end
```

Or with [`Mix.install/1`](https://hexdocs.pm/mix/Mix.html#install/2):

```elixir
Mix.install([:html5ever])
```

## Forcing compilation

By default **you don't need Rust installed** because the lib will try to download
a precompiled NIF file. In case you want to force compilation set the
`HTML5EVER_BUILD` environment variable to `true` or `1`. Alternatively you can also set the
application env `:build_from_source` to `true` in order to force the build:

```elixir
config :html5ever, Html5ever, build_from_source: true
```

You also need to add Rustler to your dependencies when you want to force
the compilation:

```elixir
def deps do
  [
    {:html5ever, "~> 0.17.0"},
    {:rustler, ">= 0.0.0", optional: true}
  ]
end
```

## License

Licensed under either of

 * Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

at your option.
