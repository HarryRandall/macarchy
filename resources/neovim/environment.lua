-- Run by Macarchy's nvim launcher before any configuration. The launcher
-- points the XDG folders inside Macarchy so Neovim keeps everything there.
-- Neovim reads them again whenever it asks for a folder, so the folders are
-- pinned here first; then the person's own values go back into the
-- environment, so terminals, git, gh and language servers started from the
-- editor see the same settings as any other shell.
local pinned = {}
for _, kind in ipairs({ "cache", "config", "data", "log", "state" }) do
  pinned[kind] = vim.fn.stdpath(kind)
end
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind)
  return pinned[kind] or stdpath(kind)
end
-- ShaDa is the one file Neovim itself places from the environment at exit.
if vim.o.shadafile == "" then
  vim.o.shadafile = pinned.state .. "/shada/main.shada"
end
local function restore()
  for _, name in ipairs({ "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "NVIM_APPNAME" }) do
    vim.env[name] = vim.env["MACARCHY_ORIGINAL_" .. name]
    vim.env["MACARCHY_ORIGINAL_" .. name] = nil
  end
  vim.env.MACARCHY_NVIM_ENVIRONMENT = nil
end
-- Neovim finds init.lua through the environment after this file runs, so
-- the values go back once it has been read, before files open and language
-- servers start. VimEnter covers starts without one, such as --clean.
local init = { [pinned.config .. "/init.lua"] = true, [pinned.config .. "/init.vim"] = true }
local group = vim.api.nvim_create_augroup("MacarchyEnvironment", {})
vim.api.nvim_create_autocmd("SourcePost", {
  group = group,
  callback = function(event)
    if init[vim.fn.fnamemodify(event.file, ":p")] then
      vim.api.nvim_del_augroup_by_id(group)
      restore()
    end
  end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  once = true,
  callback = function()
    vim.api.nvim_del_augroup_by_id(group)
    restore()
  end,
})
