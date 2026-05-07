-- LSP via lazy-lsp.nvim: Nix-based auto-discovery, no mason required
-- lsp-zero provides on_attach keymaps; blink.cmp (LazyVim default) handles capabilities
return {
  {
    "dundalek/lazy-lsp.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      { "VonHeikemen/lsp-zero.nvim", branch = "v3.x" },
    },
    config = function()
      local lsp_zero = require("lsp-zero")

      lsp_zero.on_attach(function(client, bufnr)
        -- preserve_mappings = true: don't override LazyVim's gd/gr/etc. keymaps
        lsp_zero.default_keymaps({
          buffer = bufnr,
          preserve_mappings = true,
        })
      end)

      require("lazy-lsp").setup({
        excluded_servers = {
          "ty",       -- experimental Astral type checker, unstable
          "denols",   -- conflicts with vtsls when both tsconfig and deno.json present
        },
      })
    end,
  },
}
