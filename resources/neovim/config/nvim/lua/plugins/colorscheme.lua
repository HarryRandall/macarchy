local theme = require("config.theme")

return {
  { "LazyVim/LazyVim", opts = { colorscheme = theme.colorscheme() } },
}
