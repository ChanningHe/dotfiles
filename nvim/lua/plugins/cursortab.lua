return {
  {
    "cursortab/cursortab.nvim",
    lazy = false,
    build = "cd server && go build",
    opts = {
      provider = {
        type = "mercuryapi",
        api_key_env = "MERCURY_AI_TOKEN",
      },
      keymaps = {
        accept = "<Tab>",
        partial_accept = "<S-Tab>",
        trigger = false,
      },
    },
  },
}
