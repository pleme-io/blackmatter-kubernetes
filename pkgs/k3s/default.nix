# k3s package — self-contained build, independent of nixpkgs k3s
{ lib, callPackage, ... }@args:

let
  k3s_builder = import ./builder.nix lib;
  common = opts: callPackage (k3s_builder opts);
  extraArgs = removeAttrs args [ "callPackage" ];
in
{
  k3s_1_34 =
    (common (import ./versions/1_34.nix) extraArgs).overrideAttrs {
      patches = [ ./patches/go_runc_require.patch ];
    };

  k3s_1_35 =
    (common (import ./versions/1_35.nix) extraArgs).overrideAttrs {
      patches = [ ./patches/go_runc_require.patch ];
    };
}
