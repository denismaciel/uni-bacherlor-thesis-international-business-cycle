{
  description = "Reproducible R environment for the BKK international business cycle thesis code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          rEnv = pkgs.rWrapper.override {
            packages = with pkgs.rPackages; [
              dplyr
              ggplot2
              mFilter
              tidyr
              xtable
              zoo
            ];
          };
        in
        {
          default = rEnv;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          rEnv = self.packages.${system}.default;
          runMain = pkgs.writeShellApplication {
            name = "run-thesis-code";
            runtimeInputs = [ rEnv ];
            text = ''
              Rscript "+Code.R"
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${runMain}/bin/run-thesis-code";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.default
            ];
          };
        }
      );
    };
}
