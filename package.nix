{ release, naersk, fetchurl, runCommand, unzip }:
let
  inherit (release) rev url hash;
  sourcezip = fetchurl { inherit url hash; };
  src = runCommand "extract-${rev}" { } ''
    target=$(mktemp -d)
    ${unzip}/bin/unzip "${sourcezip}" -d "$target"
    mv -v "$target/rust-analyzer-${rev}" "$out"
  '';
in naersk.buildPackage {
  pname = "rust-analyzer";
  version = rev;

  inherit src;

  cargoBuildOptions = opts: [ "-p 'rust-analyzer'" ] ++ opts;
  cargoTestOptions = opts: [ "-p 'rust-analyzer'" ] ++ opts;
  cargoDocOptions = opts: [ "-p 'rust-analyzer'" ] ++ opts;

  # If we don't do this, naersk will grab the dependencies
  # of *all* the crates in the workspace, and some of them
  # are broken and cannot be built, apparently.
  singleStep = true;
}
