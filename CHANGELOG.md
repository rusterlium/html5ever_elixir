# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/rusterlium/html5ever_elixir/compare/v0.10.1...HEAD
[0.10.1]: https://github.com/rusterlium/html5ever_elixir/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/rusterlium/html5ever_elixir/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/rusterlium/html5ever_elixir/releases/tag/v0.9.0
