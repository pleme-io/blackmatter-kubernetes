# k3s package — self-contained build, independent of nixpkgs k3s
#
# Tracks: 1.30 (eol), 1.31 (eol), 1.32 (eol), 1.33, 1.34 (default), 1.35 (latest)
{ lib, callPackage, ... }@args:

let
  k3s_builder = import ./builder.nix lib;
  common = opts: callPackage (k3s_builder opts);
  extraArgs = removeAttrs args [ "callPackage" ];
in
{
  k3s_1_30 =
    (common (import ./versions/1_30.nix) extraArgs).overrideAttrs {
      patches = [ ./patches/go_runc_require.patch ];
    };

  k3s_1_31 =
    (common (import ./versions/1_31.nix) extraArgs).overrideAttrs {
      patches = [ ./patches/go_runc_require.patch ];
    };

  k3s_1_32 =
    (common (import ./versions/1_32.nix) extraArgs).overrideAttrs {
      patches = [ ./patches/go_runc_require.patch ];
    };

  k3s_1_33 =
    (common (import ./versions/1_33.nix) extraArgs).overrideAttrs {
      patches = [ ./patches/go_runc_require.patch ];
    };

  k3s_1_34 =
    (common (import ./versions/1_34.nix) extraArgs).overrideAttrs {
      patches = [ ./patches/go_runc_require.patch ];
    };

  k3s_1_35 =
    (common (import ./versions/1_35.nix) extraArgs).overrideAttrs {
      patches = [ ./patches/go_runc_require.patch ];
    };
}
