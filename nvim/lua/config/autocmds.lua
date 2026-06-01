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

local theme_group = vim.api.nvim_create_augroup("macarchy_theme_refresh", { clear = true })
local theme = require("config.theme")
local last_colorscheme_stamp = theme.stamp()
local theme_timer = nil

local function refresh_configured_colorscheme()
  vim.schedule(function()
    local stamp = theme.stamp()
    if stamp == last_colorscheme_stamp then
      return
    end
    last_colorscheme_stamp = stamp

    local colorscheme = theme.colorscheme()
    if not colorscheme or colorscheme == vim.g.colors_name then
      clear_backgrounds()
      return
    end

    local ok, err = theme.apply(colorscheme)
    if ok then
      clear_backgrounds()
    else
      vim.g.macarchy_colorscheme_error = err
    end
  end)
end

local function start_theme_timer()
  local uv = vim.uv or vim.loop

  if theme_timer then
    return
  end

  theme_timer = uv.new_timer()
  if not theme_timer then
    return
  end

  theme_timer:start(150, 150, refresh_configured_colorscheme)
end

start_theme_timer()

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "VimResized" }, {
  group = theme_group,
  callback = refresh_configured_colorscheme,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = theme_group,
  callback = function()
    if theme_timer then
      theme_timer:stop()
      theme_timer:close()
      theme_timer = nil
    end
  end,
})

local dashboard_filetypes = {
  alpha = true,
  dashboard = true,
  ministarter = true,
  snacks_dashboard = true,
}

local function clean_dashboard_window()
  if not dashboard_filetypes[vim.bo.filetype] then
    return
  end

  vim.schedule(function()
    vim.wo.cursorline = false
    vim.wo.foldcolumn = "0"
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.scrolloff = 0
    vim.wo.sidescrolloff = 0
    vim.wo.signcolumn = "no"
    vim.wo.statuscolumn = ""
    vim.wo.winbar = ""
  end)
end

vim.api.nvim_create_autocmd("FileType", {
  group = theme_group,
  pattern = vim.tbl_keys(dashboard_filetypes),
  callback = clean_dashboard_window,
})

clean_dashboard_window()
