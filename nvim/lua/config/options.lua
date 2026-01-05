-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
local opt = vim.opt

-- Clipboard configuration
-- When in SSH, use OSC52 for clipboard sync (via vim-oscyank plugin)
-- When local, use system clipboard directly
if vim.env.SSH_CONNECTION then
  opt.clipboard = "" -- Don't use system clipboard directly in SSH
  -- OSC52 will be handled by vim-oscyank plugin
else
  opt.clipboard = "unnamedplus" -- Use system clipboard when local
end
