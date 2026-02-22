# Distribution tracks — each maps a name to a k3s version pin + metadata
#
# Tracks define supported Kubernetes versions. Each track pins a specific
# k3s release and declares the K8s version, support status, and EOL date.
#
# Combined with profiles (lib/profiles.nix), each track × profile pair
# defines a complete cluster configuration variant.
{ lib }:
let
  profileDefs = import ./profiles.nix { inherit lib; };
in {
  # All available cluster profiles
  inherit (profileDefs) profiles defaultProfile;
  tracks = {
    "1.34" = {
      kubernetesVersion = "1.34";
      k3sVersionFile = ../pkgs/k3s/versions/1_34.nix;
      status = "supported";  # supported | current | eol
      eol = "2026-10-27";
    };
    "1.35" = {
      kubernetesVersion = "1.35";
      k3sVersionFile = ../pkgs/k3s/versions/1_35.nix;
      status = "current";
      eol = "2027-02-28";
    };
  };

  # Default track for new deployments (conservative)
  defaultTrack = "1.34";

  # Latest track
  latestTrack = "1.35";

  # K8s version skew policy
  skewPolicy = {
    kubeletMaxLag = 3;     # kubelet can be up to 3 minors behind API server
    kubectlRange = 1;      # kubectl +/-1 minor from API server
    controlPlaneSkew = 1;  # HA API servers within 1 minor of each other
  };

  # Profile × track matrix — all valid combinations
  matrix = lib.listToAttrs (lib.concatMap (trackName:
    map (profileName: {
      name = "${profileName}-${trackName}";
      value = {
        track = trackName;
        profile = profileName;
      };
    }) (lib.attrNames profileDefs.profiles)
  ) (lib.attrNames {
    "1.34" = {};
    "1.35" = {};
  }));
}
