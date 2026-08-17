{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-bitcoin.url = "github:fort-nix/nix-bitcoin/release";
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
      x16 = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [./nixos/x16.nix];
      };
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
