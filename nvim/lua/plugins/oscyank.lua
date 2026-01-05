return {
  "ojroques/vim-oscyank",
  branch = "main",
  event = "VeryLazy",
  config = function()
    -- Configuration options
    vim.g.oscyank_max_length = 0 -- unlimited length
    vim.g.oscyank_silent = false -- show message on successful copy
    vim.g.oscyank_trim = 0 -- don't trim whitespaces

    -- Key mappings for manual OSC yank (backup method)
    vim.keymap.set("n", "<leader>oc", "<Plug>OSCYankOperator", { desc = "OSC Yank (operator)" })
    vim.keymap.set("n", "<leader>occ", "<leader>oc_", { remap = true, desc = "OSC Yank (line)" })
    vim.keymap.set("v", "<leader>oc", "<Plug>OSCYankVisual", { desc = "OSC Yank (visual)" })


    -- Make 'y' automatically sync with system clipboard via OSC52
    vim.api.nvim_create_autocmd("TextYankPost", {
      group = vim.api.nvim_create_augroup("OSCYankOnYank", { clear = true }),
      callback = function()
        -- Only sync when using 'y' command (not 'd' or 'c')
        if vim.v.event.operator == "y" then
          -- Copy to system clipboard via OSC52
          vim.fn.OSCYankRegister('"')
        end
      end,
    })
  end,
}

