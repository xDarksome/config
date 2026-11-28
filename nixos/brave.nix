# Brave's Auto Tab Discard settings (x16), as an enterprise policy: Brave
# hands them to the extension as its managed storage. The extension (built in
# home-manager/brave) only accepts the keys in its schema.json.
#
# The extension treats these as defaults: a setting saved in its own options
# page overrides them, and saving the options page saves every setting. If
# they don't apply, reset the extension's settings (options page, Reset,
# double-click) and leave the options page unsaved.
{pkgs, ...}: let
  autoTabDiscard = pkgs.callPackage ../home-manager/brave/auto-tab-discard.nix {};
in {
  environment.etc."brave/policies/managed/auto-tab-discard.json".text = builtins.toJSON {
    "3rdparty".extensions.${autoTabDiscard.id} = {
      # Discard every tab, pinned or not, when Brave (or the extension)
      # starts; the active tab is never discarded.
      "startup-pinned" = true;
      "startup-unpinned" = true;
      # Pinned tabs aren't protected, or startup couldn't discard them.
      "pinned" = false;
      # No minimum tab count: startup discarding applies it too, and would
      # skip discarding with 6 or fewer tabs.
      "number" = 0;
      # Never discarded, at startup or later. Covers subdomains, e.g.
      # app.slack.com and web.telegram.org.
      "whitelist" = ["slack.com" "telegram.org"];
    };
  };
}
