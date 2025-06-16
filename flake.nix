{
  description = "Gleam dev environment for Entomologist";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { nixpkgs, systems, ... }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gleam
            beamMinimal27Packages.erlang
            beamMinimal27Packages.rebar3

            # For ui css compilation and development
            tailwindcss-language-server
            tailwindcss_4
            vscode-langservers-extracted

            nodejs_24

            gitmoji-cli
            watchexec
          ] ++ lib.optional stdenv.isLinux inotify-tools;
        };
      });
    };
}
