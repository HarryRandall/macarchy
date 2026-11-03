-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Prevent accidental pasting with lowercase p.
vim.keymap.set("n", "p", "<Nop>", { desc = "Disable paste" })
