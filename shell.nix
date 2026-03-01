{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    git-crypt
    neovim
    gcc
    gnumake
    python310
    nodejs
    bash-language-server
    pyright
    clang-tools
  ];
  shellHook = ''
    export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    export WORKSPACE_ROOT="$(pwd)/.metadata"
    export LICENSES_DIR="$(pwd)/licenses"

    mkdir -p "$WORKSPACE_ROOT/.config/nvim"
    mkdir -p "$LICENSES_DIR"

    export HOME="$WORKSPACE_ROOT"
    export XDG_CONFIG_HOME="$WORKSPACE_ROOT/.config"
    export XDG_DATA_HOME="$WORKSPACE_ROOT/.local/share"
    export XDG_CACHE_HOME="$WORKSPACE_ROOT/.cache"
    export GNUPGHOME="$WORKSPACE_ROOT/.gnupg"

    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL="$WORKSPACE_ROOT/.gitconfig"
  '';
}
