# k3s package — self-contained build, independent of nixpkgs k3s
#
# Tracks: 1.30 (eol), 1.31 (eol), 1.32 (eol), 1.33, 1.34 (default), 1.35 (latest)
{ lib, callPackage, ... }@args:

let
  k3s_builder = import ./builder.nix lib;
  common = opts: callPackage (k3s_builder opts);
  extraArgs = removeAttrs args [ "callPackage" ];

  allTracks = [ "1.30" "1.31" "1.32" "1.33" "1.34" "1.35" ];
in
  lib.listToAttrs (map (track: {
    name = "k3s_${builtins.replaceStrings ["."] ["_"] track}";
    value = (common (import ./versions/${builtins.replaceStrings ["."] ["_"] track}.nix) extraArgs)
      .overrideAttrs { patches = [ ./patches/go_runc_require.patch ]; };
  }) allTracks)
