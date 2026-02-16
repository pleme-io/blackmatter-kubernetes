{
  description = "Blackmatter Kubernetes - K8s tools, K9s TUI, K3d, and cluster management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/d6c71932130818840fc8fe9509cf50be8c64634f";
  };

  outputs = { self, nixpkgs }: {
    homeManagerModules.default = import ./module;
  };
}
