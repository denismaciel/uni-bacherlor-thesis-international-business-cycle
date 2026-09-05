{
  description = "BKK thesis reproduction with Python/Polars and an R validation environment";

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
              lintr
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
          runMain = pkgs.writeShellApplication {
            name = "run-thesis-code";
            runtimeInputs = [ pkgs.uv ];
            text = ''
              uv run --locked bkk-business-cycle run
            '';
          };
          checkResults = pkgs.writeShellApplication {
            name = "check-thesis-results";
            runtimeInputs = [ pkgs.uv ];
            text = ''
              uv run --locked bkk-business-cycle check
            '';
          };
          runExtension = pkgs.writeShellApplication {
            name = "run-research-extension";
            runtimeInputs = [ self.packages.${system}.default ];
            text = ''
              Rscript "scripts/run_extension.R" "$@"
            '';
          };
          checkExtension = pkgs.writeShellApplication {
            name = "check-research-extension";
            runtimeInputs = [ self.packages.${system}.default ];
            text = ''
              Rscript "scripts/check_extension.R"
            '';
          };
          buildPaper = pkgs.writeShellApplication {
            name = "build-thesis-paper";
            runtimeInputs = [
              pkgs.uv
              self.packages.${system}.paper
            ];
            text = ''
              uv run --locked bkk-business-cycle check --figures
              latexmk -pdf -interaction=nonstopmode -halt-on-error -cd "paper/main.tex"
            '';
          };
          lintTex = pkgs.writeShellApplication {
            name = "lint-thesis-tex";
            runtimeInputs = [
              pkgs.texlivePackages.chktex
              self.packages.${system}.paper
            ];
            text = ''
              export TEXMFCNF="${self.packages.${system}.paper}/share/texmf-var/web2c:"
              chktex -q -g0 -I0 \
                -n 1 \
                -n 8 \
                -n 12 \
                -n 13 \
                -n 18 \
                -n 24 \
                -n 27 \
                -n 36 \
                -n 38 \
                -n 46 \
                paper/main.tex \
                paper/preamble.tex \
                paper/frontmatter/*.tex \
                paper/chapters/*.tex \
                paper/appendix/*.tex
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
          extension = {
            type = "app";
            program = "${runExtension}/bin/run-research-extension";
          };
          check-extension = {
            type = "app";
            program = "${checkExtension}/bin/check-research-extension";
          };
          paper = {
            type = "app";
            program = "${buildPaper}/bin/build-thesis-paper";
          };
          lint-tex = {
            type = "app";
            program = "${lintTex}/bin/lint-thesis-tex";
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
              pkgs.uv
              self.packages.${system}.default
              self.packages.${system}.paper
              pkgs.texlivePackages.chktex
            ];
          };
        }
      );
    };
}
