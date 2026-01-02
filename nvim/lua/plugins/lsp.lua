-- Additional LSP servers configuration
-- Main language support is handled by LazyVim Extras in lazy.lua
-- Only configure languages without official extras here
return {
  -- Configure nvim-lspconfig for additional LSP servers
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        -- Shell scripting
        bashls = {},

        -- HTML
        html = {},

        -- CSS
        cssls = {},
      },
    },
  },

  -- Configure mason.nvim to ensure additional tools are installed
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- Additional LSP servers not covered by extras
        "bash-language-server",
        "html-lsp",
        "css-lsp",

        -- Additional formatters
        "shfmt",      -- Shell formatter
        "shellcheck", -- Shell linter
      },
    },
  },
}
