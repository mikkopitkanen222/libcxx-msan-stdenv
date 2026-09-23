{
  pkgs ? import <nixpkgs> { },
  llvmPackages ? pkgs.llvmPackages,
  ...
}:
let
  lib = pkgs.lib;

  libcxx-msan = llvmPackages.libcxx.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-msan";
    cmakeFlags =
      let
        sharedFlags = lib.concatStringsSep " " [
          # Put sanitizer headers on the include path.
          "-isystem ${lib.getDev llvmPackages.compiler-rt-libc}/include"
          # Silence unused "-rtlib=compiler-rt" (a link-only flag) compiler warnings.
          "-Wno-unused-command-line-argument"
        ];
      in
      (oldAttrs.cmakeFlags or [ ])
      ++ (lib.mapAttrsToList lib.cmakeFeature {
        LLVM_USE_SANITIZER = "MemoryWithOrigins";
        CMAKE_C_FLAGS = sharedFlags;
        CMAKE_CXX_FLAGS = sharedFlags;
      });
  });

  # "fortify"/"fortify3" hardening unconditionally injects "-O2 -U_FORTIFY_SOURCE ...
  # -D_FORTIFY_SOURCE=2". At "-O2", clang's optimizer miscompiles functions with uninitialized
  # local reads under "-fsanitize=memory", causing the entire function body to be deleted, which
  # in turn causes crashes with "MemorySanitizer: stack-overflow"/DEADLYSIGNAL. This can be
  # countered by setting "-O0". Setting "-U_FORTIFY_SOURCE" silences glibc warnings on
  # contradictory "-O0"/"_FORTIFY_SOURCE".
  fortifyEnabledByDefault = lib.any (flag: lib.elem flag (cc-msan.defaultHardeningFlags or [ ])) [
    "fortify"
    "fortify3"
  ];
  hardeningCounterFlags = lib.optionals fortifyEnabledByDefault [
    "-O0"
    "-U_FORTIFY_SOURCE"
  ];

  cc-msan = pkgs.wrapCCWith {
    cc = llvmPackages.clang-unwrapped;
    libcxx = libcxx-msan;
    # bintools ships symbolizer; Symbolizer turns reported addresses to file:line locations.
    bintools = llvmPackages.bintools;
    extraPackages = [ llvmPackages.compiler-rt ];
    # clang-unwrapped only ships the headers.
    # compiler-rt ships the sanitizer runtime archives (libclang_rt.msan*.a).
    extraBuildCommands =
      let
        cc = llvmPackages.clang-unwrapped;
        clangMajorVersion = lib.versions.major llvmPackages.release_version;
      in
      ''
        rsrc="$out/resource-root"
        mkdir "$rsrc"
        ln -s "${lib.getLib cc}/lib/clang/${clangMajorVersion}/include" "$rsrc/include"
        ln -s "${llvmPackages.compiler-rt}/lib" "$rsrc/lib"
        ln -s "${llvmPackages.compiler-rt}/share" "$rsrc/share"
        echo "-resource-dir=$rsrc" >> $out/nix-support/cc-cflags
      '';
    # MSan requires every translation unit linked into the final binary to be instrumented.
    # Baking the flags into the wrapper itself makes every derivation built with this stdenv
    # automatically instrumented.
    nixSupport.cc-cflags = [
      "-fsanitize=memory"
      "-fno-omit-frame-pointer"
      "-fsanitize-memory-track-origins=2"
    ]
    ++ hardeningCounterFlags;
  };
in
pkgs.overrideCC llvmPackages.libcxxStdenv cc-msan
