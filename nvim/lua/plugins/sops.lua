return {
    "lemarsu/sops.nvim",
    config = function()
        local sops = require("sops")
        local config = require("sops.config")

        -- config.binary = "sops"

        -- config.binary = "/opt/homebrew/bin/sops"

        -- config.env = {
        --  SOPS_AGE_KEY = vim.fn.expand("~/.config/sops/age/keys.txt"),
        -- }

        config.follow = { "SOPS_AGE_KEY", "SOPS_AGE_KEY_FILE" }

        sops.setup()
    end,
    keys = {
        { "<leader>se", "<cmd>Sops edit<cr>",    desc = "Sops Edit" },
        { "<leader>sc", "<cmd>Sops close<cr>",   desc = "Sops Close" },
        { "<leader>st", "<cmd>Sops toggle<cr>",  desc = "Sops Toggle" },
        { "<leader>sE", "<cmd>Sops encrypt<cr>", desc = "Sops Encrypt" },
        { "<leader>sD", "<cmd>Sops decrypt<cr>", desc = "Sops Decrypt" },
        { "<leader>sv", "<cmd>Sops version<cr>", desc = "Sops Version" },
    },
}
