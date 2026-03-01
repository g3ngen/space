#!/usr/bin/env bash

IS_PUBLIC="false"
for arg in "$@"; do
  if [ "$arg" == "--public" ]; then
    IS_PUBLIC="true"
  fi
done

read -p "Project Name: " PROJECT_NAME
read -p "Remote Repository URL: " REPO_URL
read -p "GitHub Username: " GITHUB_ID
read -s -p "GitHub Token: " GITHUB_TOKEN
echo ""
read -p "Commit Author Name: " GIT_USER_NAME
read -p "Commit Author Email: " GIT_USER_EMAIL

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME" || exit

cat << 'EOF' > shell.nix
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
    ripgrep
    cacert
    xclip
  ];
  shellHook = ''
    export WORKSPACE_ROOT="$(pwd)/.metadata"
    export LICENSES_DIR="$(pwd)/licenses"
    mkdir -p "$WORKSPACE_ROOT/.config/nvim"
    mkdir -p "$LICENSES_DIR"
    export HOME="$WORKSPACE_ROOT"
    export XDG_CONFIG_HOME="$WORKSPACE_ROOT/.config"
    export XDG_DATA_HOME="$WORKSPACE_ROOT/.local/share"
    export XDG_CACHE_HOME="$WORKSPACE_ROOT/.cache"
    export GNUPGHOME="$WORKSPACE_ROOT/.gnupg"
    export NIX_SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL="$WORKSPACE_ROOT/.gitconfig"
  '';
}
EOF

mkdir -p .metadata/.config/nvim

cat << 'EOF' > .metadata/.config/nvim/init.lua
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.clipboard = "unnamedplus"

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end }
    }
  },
  {
    "neovim/nvim-lspconfig",
    version = "v0.1.8",
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local lspconfig = require("lspconfig")
      local cap = require("cmp_nvim_lsp").default_capabilities()
      local servers = { "pyright", "clangd", "bashls" }
      for _, lsp in ipairs(servers) do
        lspconfig[lsp].setup({ capabilities = cap })
      end
    end
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip", "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item()
        }),
        sources = { { name = "nvim_lsp" }, { name = "luasnip" } }
      })
    end
  }
})
EOF

if [ "$IS_PUBLIC" == "false" ]; then
  echo "* filter=git-crypt diff=git-crypt" > .gitattributes
  echo ".gitattributes !filter !diff" >> .gitattributes
  echo ".gitignore !filter !diff" >> .gitattributes
  echo "*.key" > .gitignore
fi

echo ".metadata/" >> .gitignore
echo "licenses/" >> .gitignore

nix-shell --run "
  mkdir -p licenses
  printf \"https://$GITHUB_ID:$GITHUB_TOKEN@github.com\n\" > licenses/.git-credentials
  chmod 600 licenses/.git-credentials
  git config --global user.name \"$GIT_USER_NAME\"
  git config --global user.email \"$GIT_USER_EMAIL\"
  git init
  git branch -M main
  if [ \"$IS_PUBLIC\" == \"false\" ]; then
    git-crypt init
    git-crypt export-key ./licenses/unlock.key
  fi
  git config credential.helper \"store --file=\$(pwd)/licenses/.git-credentials\"
  git remote add origin \"$REPO_URL\"
  git add .
  git commit -m \"chore: initialize secure workspace\"
  git push -u origin main
"

echo "Workspace initialized."
