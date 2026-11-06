return {
  {
    "iamcco/markdown-preview.nvim",
    init = function()
      vim.g.mkdp_filetypes = { "markdown", "markdown.mdx" }
    end,
    config = function()
      local function user_command(name, callback)
        pcall(vim.api.nvim_del_user_command, name)
        vim.api.nvim_create_user_command(name, callback, { bar = true })
      end

      user_command("MarkdownPreview", function()
        vim.fn["mkdp#util#open_preview_page"]()
      end)

      user_command("MarkdownPreviewStop", function()
        vim.fn["mkdp#util#stop_preview"]()
      end)

      user_command("MarkdownPreviewToggle", function()
        vim.fn["mkdp#util#toggle_preview"]()
      end)
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "markdown.mdx" },
    opts = {
      enabled = true,
      file_types = { "markdown", "markdown.mdx" },
      render_modes = true,
      heading = {
        icons = { "H1 ", "H2 ", "H3 ", "H4 ", "H5 ", "H6 " },
        position = "inline",
      },
      checkbox = {
        enabled = true,
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = {}
      opts.linters_by_ft["markdown.mdx"] = {}
    end,
  },
}
