{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = with pkgs; [
    git
    vhs
    ttyd
    cargo
  ];

  scripts = {
    record.exec = ''
      cd "$(git rev-parse --show-toplevel)/demo"
      vhs surround.tape
    '';
  };

  enterShell = ''
    echo "surround.hx — record  : render demo/surround.tape → demo/surround.gif"
    echo "             Note: hx (helix-steel) must be on PATH for VHS recordings."
    _LWS_LIB=$(ldd "$(which ttyd)" 2>/dev/null | grep libwebsockets | grep -oP '=> \K\S+' | xargs dirname 2>/dev/null)
    if [ -n "$_LWS_LIB" ]; then
      export LD_LIBRARY_PATH="$_LWS_LIB''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
    unset _LWS_LIB
  '';
}
