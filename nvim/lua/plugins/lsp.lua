-- Additional LSP servers configuration
-- Main language support is handled by LazyVim Extras in lazy.lua
-- Only configure languages without official extras here
return {
  -- Configure nvim-lspconfig for additional LSP servers
  -- {
  --   "neovim/nvim-lspconfig",
  --   ---@class PluginLspOpts
  --   opts = {
  --     ---@type lspconfig.options
  --     servers = {
  --       -- Shell scripting
  --       bashls = {},

  --       -- HTML
  --       html = {},

  --       -- CSS
  --       cssls = {},
  --     },
  --   },
  -- },
  {
    "dundalek/lazy-lsp.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      {"VonHeikemen/lsp-zero.nvim", branch = "v3.x"},
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/nvim-cmp",
    },
    config = function()
      local lsp_zero = require("lsp-zero")
  
      lsp_zero.on_attach(function(client, bufnr)
        -- see :help lsp-zero-keybindings to learn the available actions
        lsp_zero.default_keymaps({
          buffer = bufnr,
          preserve_mappings = false
        })
      end)
  
      require("lazy-lsp").setup {
        excluded_servers = { "ty" },
      }
    end,
  },
  -- -- Configure mason.nvim to ensure additional tools are installed
  -- {
  --   "mason-org/mason.nvim",
  --   opts = {
  --     ensure_installed = {
  --       -- Additional LSP servers not covered by extras
  --       "bash-language-server",
  --       "html-lsp",
  --       "css-lsp",

  --       -- Additional formatters
  --       "shfmt",      -- Shell formatter
  --       "shellcheck", -- Shell linter
  --     },
  --   },
  -- },
}
