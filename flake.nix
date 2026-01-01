{
  description = "ChanningHe's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    in
    {
      # Export paths for each dotfile category under 'lib' to avoid flake warnings
      # Access via: inputs.dotfiles.lib.nvimConfig, inputs.dotfiles.lib.p10kConfig, etc.
      lib = {
        nvimConfig = ./nvim;
        p10kConfig = ./p10k;

        # Future: add more dotfiles here
        # Example:
        # tmuxConfig = ./tmux;
        # gitConfig = ./git;
      };

      # Dev shell for dotfiles management
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              stylua # Lua formatter for nvim config
              nixfmt-rfc-style
            ];
          };
        }
      );
    };
}

