{
  description = "Backup script";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      elvish-tap = pkgs.stdenv.mkDerivation {
        pname = "elvish-tap";
        version = "main";

        src = pkgs.fetchFromGitHub {
          owner = "tesujimath";
          repo = "elvish-tap";
          rev = "main";
          hash = "sha256-4M3Kh814aQ0Sv075G2q8DsKCZDFx7Hi5B0kJ7OApAPg=";
        };

        installPhase = ''
          mkdir -p $out/share/elvish/lib/github.com/tesujimath/elvish-tap
          cp -r * $out/share/elvish/lib/github.com/tesujimath/elvish-tap/
        '';
      };

      default = pkgs.stdenv.mkDerivation {
        pname = "rbackup";
        version = "0.4.0";

        src = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = pkgs.lib.fileset.unions [
            ./Makefile
            ./completions
            ./lib
            ./man
            ./t
            ./rbackup
          ];
        };

        nativeBuildInputs = with pkgs; [
          makeWrapper
          pandoc
        ];
        buildPhase = ''
          make doc VERSION="$version"
        '';

        buildInputs = with pkgs; [ elvish ];

        installPhase = ''
          make install PREFIX=$out
        '';

        postFixup = ''
          patchShebangs .
          wrapProgram $out/bin/rbackup \
          --set PATH ${
            pkgs.lib.makeBinPath [
              pkgs.elvish
              pkgs.coreutils
              pkgs.zip
              pkgs.unzip
              pkgs.openssl
              pkgs.rclone
            ]
          } \
          --prefix XDG_DATA_DIRS : "$out/share" \
          --set RBACKUP_VERSION $version \
          --set RBACKUP_GIT_SHA "${self.shortRev or self.dirtyShortRev or "dirty"}"
        '';

        doCheck = true;
        nativeCheckInputs = with pkgs; [
          coreutils
          elvish
          perl
          yq
          elvish-tap
          zip
          unzip
          openssl
        ];

        preCheck = ''
          patchShebangs .
          export XDG_DATA_DIRS="${elvish-tap}/share:''${XDG_DATA_DIRS:-}"
        '';
      };

      devShell = pkgs.mkShell {
        packages = with pkgs; [
          coreutils
          elvish
          perl
          yq
          pandoc
          elvish-tap
          default
        ];

        shellHook = ''
          export RBACKUP_RCLONE_REMOTE="name:folder"
          export RBACKUP_ENCRYPT_PASSWORD="password"
          export RBACKUP_PATHS="./README.md"
        '';
      };
    in
    {
      packages.${system}.default = default;
      devShells.${system}.default = devShell;
    };
}
