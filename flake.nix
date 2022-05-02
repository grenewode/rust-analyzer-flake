{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nmattia/naersk";
    mozillapkgs = {
      url = "github:mozilla/nixpkgs-mozilla";
      flake = false;
    };
    rust-analyzer-src = {
      url = "github:rust-lang/rust-analyzer/2022-05-02";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, flake-utils, naersk, mozillapkgs, rust-analyzer-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        mozilla = pkgs.callPackage (mozillapkgs + "/package-set.nix") { };
        rust = (mozilla.rustChannelOf {
          date = "2022-05-02";
          channel = "nightly";
          sha256 = "sha256-U7DTa2ChZSiCbCYEI0yMCZ/ioSE1MRqFogMPiB7u/ts=";
        }).rust;
        naersk-lib = naersk.lib."${system}".override {
          cargo = rust;
          rustc = rust;
        };
        defaultPackage = naersk-lib.buildPackage {
          pname = "rust-analyzer";
          version = "2022-05-02";

          src = rust-analyzer-src;
          cargoBuildOptions = opts: [ "-p 'rust-analyzer'" ] ++ opts;
          cargoTestOptions = opts: [ "-p 'rust-analyzer'" ] ++ opts;
          cargoDocOptions = opts: [ "-p 'rust-analyzer'" ] ++ opts;
          singleStep = true;
        };
        defaultPackageName = (builtins.parseDrvName defaultPackage.name).name;
      in rec {
        # `nix build`
        packages = {
          ${defaultPackageName} = defaultPackage;
        } // {
          inherit rust;
        };
        inherit defaultPackage;

        # `nix run`
        apps =
          builtins.mapAttrs (name: drv: flake-utils.lib.mkApp { inherit drv; });
        defaultApp = flake-utils.lib.mkApp { drv = defaultPackage; };
      });
}
