-- LSP via lazy-lsp.nvim: Nix-based auto-discovery, no mason required.
-- lsp-zero provides on_attach keymaps; blink.cmp (LazyVim default) handles capabilities.
-- Mutually exclusive with plugins/lsp-mason.lua via `cond` (see lua/utils/has-nix.lua).
local has_nix = require("utils.has-nix").has_nix

return {
    {
        "dundalek/lazy-lsp.nvim",
        cond = has_nix,
        dependencies = {
            "neovim/nvim-lspconfig",
            { "VonHeikemen/lsp-zero.nvim", branch = "v3.x" },
        },
        config = function()
            local lsp_zero = require("lsp-zero")

            lsp_zero.on_attach(function(_, bufnr)
                -- preserve_mappings = true: don't override LazyVim's gd/gr/etc. keymaps
                lsp_zero.default_keymaps({
                    buffer = bufnr,
                    preserve_mappings = true,
                })
            end)

            require("lazy-lsp").setup({
                excluded_servers = {
                    "ty",     -- experimental Astral type checker, unstable
                    "denols", -- conflicts with vtsls when both tsconfig and deno.json present
                },
            })
        end,
    },
}
