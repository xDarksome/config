# Auto Tab Discard (https://github.com/rNeomy/auto-tab-discard), built from
# the pinned GitHub tag into a .crx for Brave to install locally, instead of
# coming from the Chrome Web Store.
#
# A .crx is signed, and the extension's ID comes from the signing key, so the
# key is fixed (./auto-tab-discard.pem) to keep the ID, and with it the
# extension's settings, the same across updates. It only signs this local
# build: using it against you would already need write access to your home
# directory. To update, bump `version`, then the source hash.
{
  stdenvNoCC,
  fetchFromGitHub,
  go-crx3,
}: let
  version = "0.7.7";
  # From the key: `crx3 id auto-tab-discard.crx`.
  id = "ilgbdppjgnofdnfonedjgoonengomehf";
in
  stdenvNoCC.mkDerivation {
    pname = "auto-tab-discard-crx";
    inherit version;

    src = fetchFromGitHub {
      owner = "rNeomy";
      repo = "auto-tab-discard";
      rev = "v${version}";
      hash = "sha256-+pdtUJRNFnGAYFMhl44gqkmNPLoi57IdJvDVSHiQKMY=";
    };

    nativeBuildInputs = [go-crx3];

    # v3/ is the Chromium (Manifest V3) version.
    buildPhase = ''
      crx3 pack v3 -p ${./auto-tab-discard.pem} -o auto-tab-discard.crx
      test "$(crx3 id auto-tab-discard.crx)" = "${id}"
    '';

    installPhase = ''
      install -Dm444 auto-tab-discard.crx $out/auto-tab-discard.crx
    '';

    passthru = {inherit id;};
  }
