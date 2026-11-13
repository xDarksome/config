{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-bitcoin.url = "github:fort-nix/nix-bitcoin/release";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
    };

    username = "darksome";

    specialArgs = {
      inherit inputs username;
    };
    extraSpecialArgs = specialArgs;
  in {
    nixosConfigurations = {
      # The existing install, with its original partitions.
      x16 = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./nixos/x16.nix
          ./nixos/x16-legacy-fs.nix
        ];
      };

      # x16 on a disk partitioned by disko. Install this one from the installer
      # ISO: `install-nixos x16-disko /dev/nvme0n1`.
      x16-disko = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./nixos/x16.nix
          inputs.disko.nixosModules.disko
          (import ./nixos/disko.nix {})
        ];
      };

      installer = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./nixos/installer
        ];
      };
    };

    # nix build .#installer-iso
    packages.${system}.installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;

    homeConfigurations = {
      core = home-manager.lib.homeManagerConfiguration {
        inherit pkgs extraSpecialArgs;
        modules = [./home-manager/core.nix];
      };

      x16 = home-manager.lib.homeManagerConfiguration {
        inherit pkgs extraSpecialArgs;
        modules = [./home-manager/x16.nix];
      };
    };
    
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;

    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        pmbootstrap
      ];
    };
  };
}
