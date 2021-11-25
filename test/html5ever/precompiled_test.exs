defmodule Html5ever.PrecompiledTest do
  use ExUnit.Case, async: true
  alias Html5ever.Precompiled

  test "target/1" do
    target_system = %{arch: "arm", vendor: "apple", os: "darwin20.3.0"}

    config = %{
      target_system: target_system,
      nif_version: "2.16",
      os_type: {:unix, :darwin}
    }

    assert {:ok, "nif-2.16-aarch64-apple-darwin"} = Precompiled.target(config)

    target_system = %{arch: "x86_64", vendor: "apple", os: "darwin20.3.0"}

    config = %{
      target_system: target_system,
      nif_version: "2.15",
      os_type: {:unix, :darwin}
    }

    assert {:ok, "nif-2.15-x86_64-apple-darwin"} = Precompiled.target(config)

    target_system = %{arch: "amd64", vendor: "pc", os: "linux", abi: "gnu"}

    config = %{
      target_system: target_system,
      nif_version: "2.14",
      os_type: {:unix, :linux}
    }

    assert {:ok, "nif-2.14-x86_64-unknown-linux-gnu"} = Precompiled.target(config)

    config = %{
      config
      | target_system: %{arch: "x86_64", vendor: "unknown", os: "linux", abi: "gnu"}
    }

    assert {:ok, "nif-2.14-x86_64-unknown-linux-gnu"} = Precompiled.target(config)

    config = %{
      target_system: %{arch: "arm", vendor: "unknown", os: "linux", abi: "gnueabihf"},
      nif_version: "2.16",
      os_type: {:unix, :linux}
    }

    assert {:ok, "nif-2.16-arm-unknown-linux-gnueabihf"} = Precompiled.target(config)

    config = %{
      target_system: %{arch: "aarch64", vendor: "unknown", os: "linux", abi: "gnu"},
      nif_version: "2.16",
      os_type: {:unix, :linux}
    }

    assert {:ok, "nif-2.16-aarch64-unknown-linux-gnu"} = Precompiled.target(config)

    config = %{
      target_system: %{arch: "aarch64", vendor: "unknown", os: "linux", abi: "gnu"},
      nif_version: "2.16",
      os_type: {:unix, :darwin}
    }

    assert {:ok, "nif-2.16-aarch64-unknown-linux-gnu"} = Precompiled.target(config)

    config = %{
      target_system: %{},
      word_size: 8,
      nif_version: "2.14",
      os_type: {:win32, :nt}
    }

    assert {:ok, "nif-2.14-x86_64-pc-windows-msvc"} = Precompiled.target(config)

    config = %{
      target_system: %{arch: "arm", vendor: "unknown", os: "linux", abi: "gnueabihf"},
      word_size: 8,
      nif_version: "2.14",
      os_type: {:win32, :nt}
    }

    assert {:ok, "nif-2.14-arm-unknown-linux-gnueabihf"} = Precompiled.target(config)

    config = %{
      target_system: %{arch: "i686", vendor: "unknown", os: "linux", abi: "gnu"},
      nif_version: "2.14",
      os_type: {:unix, :linux}
    }

    error_message =
      "precompiled NIF is not available for this target: \"i686-unknown-linux-gnu\".\nThe available targets are:\n - aarch64-apple-darwin\n - x86_64-apple-darwin\n - x86_64-unknown-linux-gnu\n - x86_64-unknown-linux-musl\n - arm-unknown-linux-gnueabihf\n - aarch64-unknown-linux-gnu\n - x86_64-pc-windows-msvc\n - x86_64-pc-windows-gnu"

    assert {:error, ^error_message} = Precompiled.target(config)
  end

  test "find_compatible_nif_version/2" do
    available = ~w(2.14 2.15 2.16)

    assert Precompiled.find_compatible_nif_version("2.14", available) == {:ok, "2.14"}
    assert Precompiled.find_compatible_nif_version("2.15", available) == {:ok, "2.15"}
    assert Precompiled.find_compatible_nif_version("2.16", available) == {:ok, "2.16"}
    assert Precompiled.find_compatible_nif_version("2.17", available) == {:ok, "2.16"}
    assert Precompiled.find_compatible_nif_version("2.13", available) == :error
    assert Precompiled.find_compatible_nif_version("3.0", available) == :error
    assert Precompiled.find_compatible_nif_version("1.0", available) == :error

    assert Precompiled.find_compatible_nif_version("2.14", ["2.14"]) == {:ok, "2.14"}
    assert Precompiled.find_compatible_nif_version("2.17", ["2.14"]) == {:ok, "2.14"}
    assert Precompiled.find_compatible_nif_version("2.13", ["2.14"]) == :error
  end

  test "maybe_override_with_env_vars/2" do
    target_system = %{
      arch: "x86_64",
      vendor: "apple",
      os: "darwin20.3.0"
    }

    assert Precompiled.maybe_override_with_env_vars(target_system, fn _ -> nil end) ==
             target_system

    env_with_targets = fn
      "TARGET_OS" -> "linux"
      "TARGET_ARCH" -> "aarch64"
      "TARGET_ABI" -> "gnu"
      _ -> nil
    end

    assert Precompiled.maybe_override_with_env_vars(target_system, env_with_targets) == %{
             arch: "aarch64",
             vendor: "unknown",
             os: "linux",
             abi: "gnu"
           }

    env_with_targets = fn
      "TARGET_OS" -> "freebsd"
      "TARGET_ARCH" -> "arm"
      "TARGET_ABI" -> "musl"
      "TARGET_VENDOR" -> "ecorp"
    end

    assert Precompiled.maybe_override_with_env_vars(target_system, env_with_targets) == %{
             arch: "arm",
             vendor: "ecorp",
             os: "freebsd",
             abi: "musl"
           }
  end
end
