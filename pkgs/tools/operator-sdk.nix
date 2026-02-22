# operator-sdk — SDK for building Kubernetes operators
# NOTE: Uses buildGoModule directly because it needs gpgme + go wrapper
{ pkgs }:
let
  version = "1.42.0";
  src = pkgs.fetchFromGitHub {
    owner = "operator-framework";
    repo = "operator-sdk";
    rev = "v${version}";
    hash = "sha256-iXLAFFO7PCxA8QuQ9pMmQ/GBbVM5wBy9cVzSQRHHPrg=";
  };
in pkgs.buildGoModule {
  pname = "operator-sdk";
  inherit version src;
  vendorHash = "sha256-F2ZYEEFG8hqCcy16DUmP9ilG6e20nXBiJnB6U+wezAo=";
  subPackages = [ "cmd/helm-operator" "cmd/operator-sdk" ];
  allowGoReference = true;
  doCheck = false;

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.pkg-config ];
  buildInputs = [ pkgs.go pkgs.gpgme ];

  postFixup = ''
    wrapProgram $out/bin/operator-sdk --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.go ]}
  '';

  meta = {
    description = "SDK for building Kubernetes operators";
    homepage = "https://github.com/operator-framework/operator-sdk";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "operator-sdk";
    platforms = pkgs.lib.platforms.linux ++ pkgs.lib.platforms.darwin;
  };
}
