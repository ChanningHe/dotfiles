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
                -- Legacy lspconfig framework is frozen; newer servers (e.g. tsc) exist only under lsp/.
                use_vim_lsp_config = true,
                excluded_servers = {
                    "ty",     -- experimental Astral type checker, unstable
                    "denols", -- conflicts with ts_ls when both tsconfig and deno.json present
                },
                -- tsc and ts_ls both claim these filetypes; vtsls has no nix package in lazy-lsp.
                preferred_servers = {
                    typescript = { "ts_ls" },
                    typescriptreact = { "ts_ls" },
                    javascript = { "ts_ls" },
                    javascriptreact = { "ts_ls" },
                },
            })
        end,
    },
}
