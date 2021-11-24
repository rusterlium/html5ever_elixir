defmodule Html5ever.PrecompiledTest do
  use ExUnit.Case, async: true
  alias Html5ever.Precompiled

  test "target/1" do
    config = %{
      system_arch: %{arch: "arm", vendor: "apple", os: "darwin20.3.0"},
      nif_version: "2.16",
      os_type: {:unix, :darwin}
    }

    assert {:ok, "nif-2.16-aarch64-apple-darwin"} = Precompiled.target(config)

    config = %{
      config
      | system_arch: %{arch: "x86_64", vendor: "apple", os: "darwin20.3.0"},
        nif_version: "2.15"
    }

    assert {:ok, "nif-2.15-x86_64-apple-darwin"} = Precompiled.target(config)

    config = %{
      system_arch: %{arch: "amd64", vendor: "pc", os: "linux", abi: "gnu"},
      nif_version: "2.14",
      os_type: {:unix, :linux}
    }

    assert {:ok, "nif-2.14-x86_64-unknown-linux-gnu"} = Precompiled.target(config)

    config = %{
      config
      | system_arch: %{arch: "x86_64", vendor: "unknown", os: "linux", abi: "gnu"}
    }

    assert {:ok, "nif-2.14-x86_64-unknown-linux-gnu"} = Precompiled.target(config)

    config = %{
      system_arch: %{arch: "arm", vendor: "buildroot", os: "linux", abi: "gnueabihf"},
      nif_version: "2.16",
      os_type: {:unix, :linux}
    }

    assert {:ok, "nif-2.16-arm-unknown-linux-gnueabihf"} = Precompiled.target(config)

    config = %{
      system_arch: %{arch: "aarch64", vendor: "buildroot", os: "linux", abi: "gnu"},
      nif_version: "2.16",
      os_type: {:unix, :linux}
    }

    assert {:ok, "nif-2.16-aarch64-unknown-linux-gnu"} = Precompiled.target(config)

    config = %{
      system_arch: %{},
      word_size: 8,
      nif_version: "2.14",
      os_type: {:win32, :nt}
    }

    assert {:ok, "nif-2.14-x86_64-pc-windows-msvc"} = Precompiled.target(config)

    config = %{
      system_arch: %{arch: "i686", vendor: "unknown", os: "linux", abi: "gnu"},
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
end
