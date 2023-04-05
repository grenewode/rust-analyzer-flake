{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nmattia/naersk";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, naersk, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        inherit (pkgs.lib)
          importJSON removeSuffix pipe mapAttrsToList concatStrings removePrefix;
        inherit (pkgs.lib.filesystem) listFilesRecursive;

        rust = pkgs.rust-bin.stable.latest.minimal;

        naersk' = pkgs.callPackage naersk {
          cargo = rust;
          rustc = rust;
        };

        mkRelease = release:
          pkgs.callPackage ./package.nix {
            inherit release;

            naersk = naersk';
          };

        releases = builtins.listToAttrs (map (releaseFile: {
          name = let
            version =
              pipe releaseFile [ builtins.baseNameOf (removeSuffix ".json") ];
          in "rust-analyzer-${version}";
          value = mkRelease (importJSON releaseFile);
        }) (listFilesRecursive ./.releases));

        defaultPackage = releases.rust-analyzer-nightly;

      in rec {
        # `nix build`
        packages = releases // {
          rust-analyzer = defaultPackage;
          default = defaultPackage;
        };

        inherit defaultPackage;

        # `nix run`
        apps =
          builtins.mapAttrs (name: drv: flake-utils.lib.mkApp { inherit drv; }) releases;
        defaultApp = flake-utils.lib.mkApp { drv = defaultPackage; };
      });
}
