local M = {}

local config_home = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
local generated_dir = vim.env.MACARCHY_GENERATED_DIR or (config_home .. "/macarchy/generated")
M.state_file = generated_dir .. "/nvim-colorscheme"

local fallback = "gruvbox"

local plugins = {
  ["catppuccin"] = "catppuccin",
  ["flexoki"] = "flexoki",
  ["flexoki-light"] = "flexoki",
  ["gruvbox"] = "gruvbox.nvim",
  ["kanagawa-wave"] = "kanagawa.nvim",
  ["nord"] = "nord.nvim",
  ["rose-pine-dawn"] = "rose-pine",
  ["rose-pine-main"] = "rose-pine",
  ["rose-pine-moon"] = "rose-pine",
  ["tokyonight-night"] = "tokyonight.nvim",
}

local function clean_name(value)
  value = tostring(value or ""):match("^%s*(.-)%s*$")
  if value:match("^[%w%._%-]+$") then
    return value
  end
end

function M.colorscheme()
  local ok, lines = pcall(vim.fn.readfile, M.state_file)
  if ok and type(lines) == "table" then
    return clean_name(lines[1]) or fallback
  end

  return fallback
end

function M.stamp()
  local stat = (vim.uv or vim.loop).fs_stat(M.state_file)
  if not stat then
    return "missing"
  end

  return ("%s:%s"):format(stat.mtime.sec, stat.mtime.nsec)
end

function M.load_plugin(colorscheme)
  local plugin = plugins[colorscheme]
  if not plugin then
    return
  end

  local ok, lazy = pcall(require, "lazy")
  if ok then
    pcall(lazy.load, { plugins = { plugin } })
  end
end

function M.apply(colorscheme)
  colorscheme = clean_name(colorscheme) or M.colorscheme()

  local ok, err = pcall(vim.cmd.colorscheme, colorscheme)
  if ok then
    return true
  end

  M.load_plugin(colorscheme)
  ok, err = pcall(vim.cmd.colorscheme, colorscheme)
  if ok then
    return true
  end

  return false, err
end

return M
