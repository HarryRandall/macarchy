return {
    {
        "bjarneo/aether.nvim",
        branch = "v2",
        name = "aether",
        priority = 1000,
        opts = {
            transparent = false,
            colors = {
                -- Background colors
                bg = "#141010",
                bg_dark = "#141010",
                bg_highlight = "#ab9191",

                -- Foreground colors
                -- fg: Object properties, builtin types, builtin variables, member access, default text
                fg = "#ffffff",
                -- fg_dark: Inactive elements, statusline, secondary text
                fg_dark = "#ffffff",
                -- comment: Line highlight, gutter elements, disabled states
                comment = "#ab9191",

                -- Accent colors
                -- red: Errors, diagnostics, tags, deletions, breakpoints
                red = "#c92b50",
                -- orange: Constants, numbers, current line number, git modifications
                orange = "#d42b5b",
                -- yellow: Types, classes, constructors, warnings, numbers, booleans
                yellow = "#ebbd5b",
                -- green: Comments, strings, success states, git additions
                green = "#ead94d",
                -- cyan: Parameters, regex, preprocessor, hints, properties
                cyan = "#14aae0",
                -- blue: Functions, keywords, directories, links, info diagnostics
                blue = "#1d52a1",
                -- purple: Storage keywords, special keywords, identifiers, namespaces
                purple = "#9368d7",
                -- magenta: Function declarations, exception handling, tags
                magenta = "#e3caec",
            },
        },
        config = function(_, opts)
            require("aether").setup(opts)
            vim.cmd.colorscheme("aether")

            -- Enable hot reload
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
