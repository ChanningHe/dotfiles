-- Mason-based LSP fallback for non-Nix environments.
-- Mutually exclusive with plugins/lsp.lua via `cond` (see lua/utils/has-nix.lua).
-- Only mason-lspconfig is gated; mason.nvim itself stays unconditional so LazyVim
-- core formatters/linters keep working in Nix env without LSP duplication.
-- blink.cmp capabilities are injected globally by LazyVim into lspconfig.util.default_config.
local has_nix = require("utils.has-nix").has_nix
local function no_nix()
  return not has_nix()
end

local servers = {
  "lua_ls",
  "vtsls",
  "basedpyright",
  "rust_analyzer",
  "gopls",
  "nil_ls",
  "jsonls",
  "bashls",
  "yamlls",
}

return {
  {
    "mason-org/mason-lspconfig.nvim",
    cond = no_nix,
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
      { "VonHeikemen/lsp-zero.nvim", branch = "v3.x" },
    },
    config = function()
      local lsp_zero = require("lsp-zero")

      lsp_zero.on_attach(function(_, bufnr)
        lsp_zero.default_keymaps({
          buffer = bufnr,
          preserve_mappings = true,
        })
      end)

      require("mason-lspconfig").setup({
        ensure_installed = servers,
        automatic_installation = true,
      })

      -- Setup each server explicitly. Robust across mason-lspconfig v1/v2
      -- (v2 removed the `handlers` API in favor of vim.lsp.config / automatic_enable).
      local lspconfig = require("lspconfig")
      for _, name in ipairs(servers) do
        local ok, err = pcall(function()
          lspconfig[name].setup({})
        end)
        if not ok then
          vim.notify("lspconfig setup failed for " .. name .. ": " .. tostring(err), vim.log.levels.WARN)
        end
      end
    end,
  },
}
