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
              readr
              tidyr
              xtable
              zoo
            ];
          };
          paperTex = pkgs.texlive.combined.scheme-full;
        in
        {
          default = rEnv;
          paper = paperTex;
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
              Rscript -e 'invisible(suppressWarnings(capture.output(source("R/main.R")))); message("Thesis code completed.")'
            '';
          };
          checkResults = pkgs.writeShellApplication {
            name = "check-thesis-results";
            runtimeInputs = [ rEnv ];
            text = ''
              Rscript "scripts/export_results.R"
              Rscript "scripts/compare_results.R"
            '';
          };
          buildPaper = pkgs.writeShellApplication {
            name = "build-thesis-paper";
            runtimeInputs = [
              rEnv
              self.packages.${system}.paper
            ];
            text = ''
              Rscript "scripts/export_results.R"
              Rscript "scripts/export_figures.R"
              latexmk -pdf -interaction=nonstopmode -halt-on-error -cd "paper/main.tex"
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${runMain}/bin/run-thesis-code";
          };
          check = {
            type = "app";
            program = "${checkResults}/bin/check-thesis-results";
          };
          paper = {
            type = "app";
            program = "${buildPaper}/bin/build-thesis-paper";
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
              self.packages.${system}.paper
            ];
          };
        }
      );
    };
}
