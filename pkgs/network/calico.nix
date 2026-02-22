# Calico components — built from the Calico monorepo
#
# Factory-style derivation: pass `component` to select which Calico
# binary to build. All share the same source and vendorHash.
{ mkGoTool, pkgs, component }:

let
  version = "3.31.3";
  src = pkgs.fetchFromGitHub {
    owner = "projectcalico";
    repo = "calico";
    rev = "v${version}";
    hash = "sha256-w+dStKYbytNekl3HxBAek8kS+FC5Aeu7OEU4SIFLURY=";
  };

  vendorHash = "sha256-J9X7W7UozsxNlXQwXYeDi++KkyjxwtnYvs4EkUq4Vec=";

  components = {
    calico-cni-plugin = {
      subPackages = [ "cni-plugin/cmd/calico" "cni-plugin/cmd/install" ];
      mainProgram = "calico";
      description = "Calico CNI plugin";
    };
    calico-apiserver = {
      subPackages = [ "apiserver/cmd/apiserver" ];
      mainProgram = "apiserver";
      description = "Calico API server";
    };
    calico-typha = {
      subPackages = [ "typha/cmd/calico-typha" ];
      mainProgram = "calico-typha";
      description = "Calico Typha daemon — fan-out proxy for Calico datastore";
    };
    calico-kube-controllers = {
      subPackages = [ "kube-controllers/cmd/kube-controllers" "kube-controllers/cmd/check-status" ];
      mainProgram = "kube-controllers";
      description = "Calico Kubernetes controllers";
      doCheck = false; # needs network + docker
    };
    calico-pod2daemon = {
      subPackages = [ "pod2daemon/csidriver" "pod2daemon/flexvol" "pod2daemon/nodeagent" ];
      mainProgram = "flexvol";
      description = "Calico pod-to-daemon communication drivers";
    };
    confd-calico = {
      subPackages = [ "confd" ];
      mainProgram = "confd";
      description = "Calico configuration daemon (confd fork)";
    };
  };

  comp = components.${component};
in mkGoTool pkgs {
  pname = component;
  inherit version src vendorHash;
  inherit (comp) subPackages;
  doCheck = comp.doCheck or false;
  description = comp.description;
  platforms = pkgs.lib.platforms.linux;
  homepage = "https://www.tigera.io/project-calico/";
  extraAttrs = {
    meta.mainProgram = comp.mainProgram;
  };
}
