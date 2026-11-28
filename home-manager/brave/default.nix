# Brave (x16), with Auto Tab Discard built from its GitHub source
# (./auto-tab-discard.nix). home-manager writes Brave's "External Extensions"
# entry for the local .crx; Brave installs it on its next start.
{pkgs, ...}: let
  autoTabDiscard = pkgs.callPackage ./auto-tab-discard.nix {};
in {
  programs.brave = {
    enable = true;
    extensions = [
      {
        inherit (autoTabDiscard) id version;
        crxPath = "${autoTabDiscard}/auto-tab-discard.crx";
      }
    ];
  };
}
