-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local transparent_group = vim.api.nvim_create_augroup("macarchy_transparent_background", { clear = true })

local function clear_backgrounds()
  local highlights = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "FloatTitle",
    "EndOfBuffer",
    "SignColumn",
    "LineNr",
    "CursorLineNr",
    "CursorLine",
    "CursorColumn",
    "ColorColumn",
    "Folded",
    "FoldColumn",
    "StatusLine",
    "StatusLineNC",
    "WinSeparator",
    "VertSplit",
  }

  for _, group in ipairs(highlights) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = transparent_group,
  callback = clear_backgrounds,
})

clear_backgrounds()
