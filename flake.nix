{
  description = "MSan-instrumented clang+libc++ Nix stdenv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default-linux";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      flake-parts,
      systems,
      treefmt-nix,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ treefmt-nix.flakeModule ];

      systems = import systems;

      perSystem = { config, pkgs, ... }: {
        packages.default = import ./default.nix { inherit pkgs; };

        checks.default =
          let
            stdenv = config.packages.default;
          in
          stdenv.mkDerivation {
            name = "libcxx-msan-stdenv-catches-uninitialized-read";
            dontUnpack = true;
            buildPhase = ''
              cat > test.cpp <<'EOF'
              int main() {
                int a;
                if (a == 42) return 1;
                return 0;
              }
              EOF
              $CXX -g -std=c++17 test.cpp -o test

              set +e
              MSAN_OPTIONS="exitcode=99" ./test >output.log 2>&1
              code=$?
              set -e

              if [ $code -ne 99 ]; then
                echo "FAIL: expected MemorySanitizer to catch the uninitialized read and exit 99, got exit code $code instead" >&2
                cat output.log >&2
                exit 1
              fi

              if ! grep -q "WARNING: MemorySanitizer: use-of-uninitialized-value" output.log; then
                echo "FAIL: process exited 99, but the expected MemorySanitizer report text wasn't found in output" >&2
                cat output.log >&2
                exit 1
              fi
            '';
            installPhase = "touch $out";
          };

        treefmt = {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt = {
              enable = true;
              strict = true;
              width = 100;
            };
            yamlfmt = {
              enable = true;
              settings.formatter = {
                type = "basic";
                retain_line_breaks_single = true;
                max_line_length = 100;
                indentless_arrays = true;
                trim_trailing_whitespace = true;
                eof_newline = true;
                force_array_style = "block";
              };
            };
          };
        };
      };
    };
}
