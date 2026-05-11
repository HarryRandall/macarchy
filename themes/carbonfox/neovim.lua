return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#161616",
        dark_bg    = "#111111",
        darker_bg  = "#0b0b0b",
        lighter_bg = "#2d2d2d",

        fg         = "#f2f4f8",
        dark_fg    = "#b6b7ba",
        light_fg   = "#f4f6f9",
        bright_fg  = "#f5f7fa",
        muted      = "#484848",

        red        = "#ee5396",
        yellow     = "#08bdba",
        orange     = "#f16da6",
        green      = "#33b1ff",
        cyan       = "#25be6a",
        blue       = "#78a9ff",
        purple     = "#be95ff",
        brown      = "#914164",

        bright_red    = "#f16da6",
        bright_yellow = "#2dc7c4",
        bright_green  = "#52bdff",
        bright_cyan   = "#46c880",
        bright_blue   = "#8cb6ff",
        bright_purple = "#c8a5ff",

        accent               = "#78a9ff",
        cursor               = "#f2f4f8",
        foreground           = "#f2f4f8",
        background           = "#161616",
        selection             = "#2d2d2d",
        selection_foreground = "#f2f4f8",
        selection_background = "#2d2d2d",
      },
    },
    -- set up hot reload
    config = function(_, opts)
      require("aether").setup(opts)
      vim.cmd.colorscheme("aether")
      require("aether.hotreload").setup()
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
