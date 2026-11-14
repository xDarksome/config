# Package a Nushell script as a command. Like pkgs.writers.writeNuBin, but PATH
# and the environment variables are set at the top of the script instead of in
# a wrapper, so they survive the script re-running itself with sudo (which
# drops the wrapper's environment). The script is parse-checked at build time.
{pkgs, lib}: {
  name,
  file,
  runtimeInputs ? [],
  env ? {},
}: let
  nu = lib.getExe pkgs.nushell;
  # JSON strings and lists are valid Nushell literals.
  prelude = lib.concatLines (
    ["$env.PATH = (${builtins.toJSON (map (p: "${lib.getBin p}/bin") runtimeInputs)} | append $env.PATH)"]
    ++ lib.mapAttrsToList (key: value: "$env.${key} = ${builtins.toJSON (toString value)}") env
  );
  check = pkgs.writeShellScript "nu-check" ''
    ${nu} --no-config-file --commands "nu-check --debug '$1'" >/dev/null
  '';
in
  pkgs.writers.writeNuBin name {inherit check;} (prelude + builtins.readFile file)
