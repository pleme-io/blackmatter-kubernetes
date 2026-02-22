# krew — kubectl plugin manager
# NOTE: Uses buildGoModule directly because it needs makeWrapper + git in PATH
{ pkgs }:
let
  version = "0.4.5";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "krew";
    rev = "v${version}";
    hash = "sha256-3GoC2HEp9XJe853/JYvX9kAAcFf7XxglVEeU9oQ/5Ms=";
  };
in pkgs.buildGoModule {
  pname = "krew";
  inherit version src;
  vendorHash = "sha256-r4Dywm0+YxWWD59oaKodkldE2uq8hlt9MwOMYDaj6Gc=";
  subPackages = [ "cmd/krew" ];
  doCheck = false;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postFixup = ''
    wrapProgram $out/bin/krew \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.gitMinimal ]}
  '';
  meta = {
    description = "Package manager for kubectl plugins";
    homepage = "https://github.com/kubernetes-sigs/krew";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "krew";
  };
}
