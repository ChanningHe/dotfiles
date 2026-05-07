-- Detect Nix availability for LSP backend selection.
-- Used by lazy.nvim `cond` to mutually exclude lazy-lsp vs mason fallback.
local M = {}

function M.has_nix()
  return vim.fn.executable("nix") == 1 or vim.fn.executable("nix-shell") == 1
end

return M
