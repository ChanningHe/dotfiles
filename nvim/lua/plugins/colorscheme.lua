-- miasma.nvim color scheme configuration
-- https://github.com/xero/miasma.nvim
return {
  -- Add miasma theme
  {
    "xero/miasma.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd("colorscheme miasma")
    end,
  },
  -- Configure LazyVim to use miasma as default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "miasma",
    },
  },
}

