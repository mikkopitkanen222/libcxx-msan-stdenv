<div align="center">

# libcxx-msan-stdenv

**MSan-instrumented clang+libc++ Nix stdenv**

<p>
<a href="https://github.com/mikkopitkanen222/libcxx-msan-stdenv/actions/workflows/checks.yml">
<img alt="GitHub master branch status" src="https://github.com/mikkopitkanen222/libcxx-msan-stdenv/actions/workflows/checks.yml/badge.svg"/>
</a>
</p>

</div>

[MemorySanitizer](https://clang.llvm.org/docs/MemorySanitizer.html) (MSan) is a dynamic analysis tool used to detect uses of uninitialized memory at runtime.
In order to avoid false positives, all translation units linked into the final binary must be instrumented (compiled with MSan).
This includes libc++ (the standard library), as well.

`libcxx-msan-stdenv` is a drop-in replacement Nix [stdenv](https://ryantm.github.io/nixpkgs/stdenv/stdenv/).
It's built with an MSan-instrumented libc++, and will automatically instrument any derivations built with it.

## Usage

### Stable Nix, No Flakes

```nix
let
  pkgs = import <nixpkgs> { };
  libcxx-msan-stdenv = builtins.fetchTarball "https://github.com/mikkopitkanen222/libcxx-msan-stdenv/archive/master.tar.gz";
  stdenv = import libcxx-msan-stdenv { inherit pkgs; };
  # or with a specific LLVM version:
  # stdenv = import libcxx-msan-stdenv { inherit pkgs; llvmPackages = pkgs.llvmPackages_23; };
in
# ...
```

### Flakes

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    libcxx-msan-stdenv = {
      url = "github:mikkopitkanen222/libcxx-msan-stdenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, libcxx-msan-stdenv, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      stdenv = import libcxx-msan-stdenv { inherit pkgs; };
      # or with a specific LLVM version:
      # stdenv = import libcxx-msan-stdenv { inherit pkgs; llvmPackages = pkgs.llvmPackages_23; };
    in
    { /* ... */ };
}
```

### Example

This builds `package.nix` with MSan-instrumentation, on Clang 23.
If any dependencies are linked into the final binary (e.g. `gtest`), they must also be instrumented.

```nix
# default.nix
let
  pkgs = import <nixpkgs> { };
  libcxx-msan-stdenv = builtins.fetchTarball "https://github.com/mikkopitkanen222/libcxx-msan-stdenv/archive/master.tar.gz";
  stdenv = import libcxx-msan-stdenv { inherit pkgs; llvmPackages = pkgs.llvmPackages_23; };
in
pkgs.callPackage ./package.nix { inherit stdenv; }
```

```nix
# package.nix
{ stdenv, gtest }:
stdenv.mkDerivation {
  # ...
  buildInputs = [ (gtest.override { inherit stdenv; }) ];
  # ...
}
```

## License

This project is licensed under the terms of the MIT license.
