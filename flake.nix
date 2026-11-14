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
      # ISO with `install-nixos`.
      x16-disko = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./nixos/x16.nix
          inputs.disko.nixosModules.disko
          ./nixos/disko.nix
        ];
      };

      # Small disko host for the installer VM test (tests/installer.nix).
      installer-test = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          inputs.disko.nixosModules.disko
          ./tests/installer-test-host.nix
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

    packages.${system} = {
      # nix build .#installer-iso
      installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;

      # Try the ISO by hand in a VM: nix run .#installer-vm
      installer-vm = import ./tests/installer-vm.nix {
        inherit pkgs;
        iso = self.packages.${system}.installer-iso;
      };
    };

    # Boot the ISO in a VM, install a test host and boot it: nix flake check
    checks.${system}.installer = import ./tests/installer.nix {
      inherit pkgs username;
      inherit (self.nixosConfigurations) installer;
    };

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
