# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.14.1] - 2023-05-20

### Added

- Add support for `rustler_precompiled` v0.6.

### Changed

- Update Rustler version in the crate from `v0.26` to `v0.28`.
  This shouldn't break anything, but would require the installation of rustler `v0.28`
  if needed in the Elixir side.

- Change the Rust edition to 2021 (it was 2018). This shouldn't change any behaviour.

## [0.14.0] - 2022-11-04

### Changed

- Require `rustler_precompiled` equal or above `v0.5.2` - thanks [@Benjamin-Philip](https://github.com/Benjamin-Philip).
- Use `Application.compile_env/3` instead of `Application.get_env/3` in the native module.

## [0.13.1] - 2022-06-24

### Fixed

- Fix the precompilation build for targets using `cross` by adding a `Cross.toml`
file with a setting telling to read the `RUSTLER_NIF_VERSION` env var from the host machine.

## [0.13.0] - 2022-04-28

### Changed

- Bump requirement for `rustler_precompiled` to `~> v0.4`. This is needed to avoid installing Rustler by default.
- Bump `html5ever` (Rust crate) to `v0.26.0`.

## [0.12.0] - 2022-03-14

### Changed

- Start using [`rustler_precompiled`](https://hex.pm/packages/rustler_precompiled) as
dependency.

## [0.11.0] - 2021-12-15

### Security

- Add checksum verification of precompiled NIF files before extracting
them to the correct location. This is to avoid supply chain attacks.
With this change we added a new mix task to download all the files
and generate the checksum before publishing the package. Additionally
the user can download only the local NIF file with the checksum.
See the `RELEASE_CHECKLIST.md` file for details on how we ensure this
works correctly.

### Removed

- Remove support for Elixir 1.10 and below. This is to keep a policy of
supporting the latest three Elixir versions.

### Changed

- Switch from thread pool to being a dirty NIF. This prevents the 
resulting term from having to be sent between processes, and therefore 
prevents an extra copy from having to be performed.
- In the FlatSink implementation for the NIF, track children in a pool
instead of allocating new vectors for every node. This significantly
reduces allocator pressure while parsing, and improves performance.
- When converting a parsed FlatSink into its term representation,
use a common child node stack instead of allocating a new one for every
node. This significantly reduces allocator pressure while creating terms, 
and improves performance.
- Start using LTO for the NIF compilation. This reduces the build size
and improves performance.

### Fixed

- Fix the target selection when using `TARGET_*` env vars on macOS.

## [0.10.1] - 2021-11-24

### Fixed

- It provides a precompiled NIF for ARM 64 bits running on Linux. This
is needed for Raspberry PI 4.

## [0.10.0] - 2021-11-24

### Added

- Add the ability to download precompiled NIFs. We provide compiled
NIF files in our GitHub releases page (from GitHub Actions) and the
lib will try to download the correct NIF respecting the OS, NIF version
and architecture of your build machine. This also works for Nerves
projects that compiles to different targets. This way the Rust toolchain
is not needed for most of people using this project.

### Fixed

- Fix compilation on macOS.

## [0.9.0] - 2021-10-02

### Added

- Add support for OTP 24. This was achieved by updating Rustler to v0.22.

[Unreleased]: https://github.com/rusterlium/html5ever_elixir/compare/v0.14.1...HEAD
[0.14.1]: https://github.com/rusterlium/html5ever_elixir/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/rusterlium/html5ever_elixir/compare/v0.13.1...v0.14.0
[0.13.1]: https://github.com/rusterlium/html5ever_elixir/compare/v0.13.0...v0.13.1
[0.13.0]: https://github.com/rusterlium/html5ever_elixir/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/rusterlium/html5ever_elixir/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/rusterlium/html5ever_elixir/compare/v0.10.1...v0.11.0
[0.10.1]: https://github.com/rusterlium/html5ever_elixir/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/rusterlium/html5ever_elixir/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/rusterlium/html5ever_elixir/releases/tag/v0.9.0
