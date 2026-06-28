return {
    { "wakatime/vim-wakatime", lazy = false },
    {
        "m4xshen/hardtime.nvim",
        lazy = false,
        dependencies = { "MunifTanjim/nui.nvim" },
        opts = {
            -- Default is { "", "i" }: arrows blocked in insert mode too.
            -- Keep them blocked in normal/visual ("") but allow in insert.
            disabled_keys = {
                ["<Up>"] = { "" },
                ["<Down>"] = { "" },
                ["<Left>"] = { "" },
                ["<Right>"] = { "" },
            },
        },
    },
    {
        "lambdalisue/vim-suda",
        cmd = { "SudaRead", "SudaWrite" },
        keys = {
            { "<leader>W", "<cmd>SudaWrite<CR>", desc = "Sudo save" },
        },
    },
    -- {
    --     "cursortab/cursortab.nvim",
    --     lazy = false,
    --     build = "cd server && go build",
    --     opts = {
    --         provider = {
    --             type = "mercuryapi",
    --             api_key_env = "MERCURY_AI_TOKEN",
    --         },
    --         keymaps = {
    --             accept = "<Tab>",
    --             partial_accept = "<S-Tab>",
    --             trigger = false,
    --         },
    --     },
    -- },
}
