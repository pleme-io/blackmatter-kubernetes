# Distribution tracks — each maps a name to a k3s version pin + metadata
#
# Tracks define supported Kubernetes versions. Each track pins a specific
# k3s release and declares the K8s version, support status, and EOL date.
#
# Combined with profiles (lib/profiles.nix), each track x profile pair
# defines a complete cluster configuration variant.
{ lib }:
let
  profileDefs = import ./profiles.nix { inherit lib; };

  allTrackNames = [ "1.30" "1.31" "1.32" "1.33" "1.34" "1.35" ];
in {
  # All available cluster profiles
  inherit (profileDefs) profiles defaultProfile;

  tracks = {
    "1.30" = {
      kubernetesVersion = "1.30";
      k3sVersionFile = ../pkgs/k3s/versions/1_30.nix;
      status = "eol";
      eol = "2025-06-28";
    };
    "1.31" = {
      kubernetesVersion = "1.31";
      k3sVersionFile = ../pkgs/k3s/versions/1_31.nix;
      status = "eol";
      eol = "2025-10-28";
    };
    "1.32" = {
      kubernetesVersion = "1.32";
      k3sVersionFile = ../pkgs/k3s/versions/1_32.nix;
      status = "eol";
      eol = "2026-02-28";
    };
    "1.33" = {
      kubernetesVersion = "1.33";
      k3sVersionFile = ../pkgs/k3s/versions/1_33.nix;
      status = "supported";
      eol = "2026-06-28";
    };
    "1.34" = {
      kubernetesVersion = "1.34";
      k3sVersionFile = ../pkgs/k3s/versions/1_34.nix;
      status = "supported";
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

  # Profile x track matrix — all valid combinations
  matrix = lib.listToAttrs (lib.concatMap (trackName:
    map (profileName: {
      name = "${profileName}-${trackName}";
      value = {
        track = trackName;
        profile = profileName;
      };
    }) (lib.attrNames profileDefs.profiles)
  ) allTrackNames);
}
