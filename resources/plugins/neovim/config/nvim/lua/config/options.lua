-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.cmdheight = 0

-- Do not highlight the matching bracket under the cursor.
vim.g.loaded_matchparen = 1

vim.filetype.add({
  pattern = {
    [".*/FINM3006/.*%.txt"] = function(_, bufnr)
      local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""

      if first_line:match("^#%s") then
        return "markdown"
      end
    end,
  },
})
