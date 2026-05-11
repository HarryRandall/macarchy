--  .S_SSSs     .S     S.    .S_SSSs     .S    S.     sSSs   .S_sSSs     .S   .S_sSSs      sSSSSs  
-- .SS~SSSSS   .SS     SS.  .SS~SSSSS   .SS    SS.   d%%SP  .SS~YS%%b   .SS  .SS~YS%%b    d%%%%SP  
-- S%S   SSSS  S%S     S%S  S%S   SSSS  S%S    S&S  d%S'    S%S   `S%b  S%S  S%S   `S%b  d%S'      
-- S%S    S%S  S%S     S%S  S%S    S%S  S%S    d*S  S%S     S%S    S%S  S%S  S%S    S%S  S%S       
-- S%S SSSS%S  S%S     S%S  S%S SSSS%S  S&S   .S*S  S&S     S%S    S&S  S&S  S%S    S&S  S&S       
-- S&S  SSS%S  S&S     S&S  S&S  SSS%S  S&S_sdSSS   S&S_Ss  S&S    S&S  S&S  S&S    S&S  S&S       
-- S&S    S&S  S&S     S&S  S&S    S&S  S&S~YSSY%b  S&S~SP  S&S    S&S  S&S  S&S    S&S  S&S       
-- S&S    S&S  S&S     S&S  S&S    S&S  S&S    `S%  S&S     S&S    S&S  S&S  S&S    S&S  S&S sSSs  
-- S*S    S&S  S*S     S*S  S*S    S&S  S*S     S%  S*b     S*S    S*S  S*S  S*S    S*S  S*b `S%%  
-- S*S    S*S  S*S  .  S*S  S*S    S*S  S*S     S&  S*S.    S*S    S*S  S*S  S*S    S*S  S*S   S%  
-- S*S    S*S  S*S_sSs_S*S  S*S    S*S  S*S     S&   SSSbs  S*S    S*S  S*S  S*S    S*S   SS_sSSS  
-- SSS    S*S  SSS~SSS~S*S  SSS    S*S  S*S     SS    YSSP  S*S    SSS  S*S  S*S    SSS    Y~YSSY  
--        SP                       SP   SP                  SP          SP   SP                    
--        Y                        Y    Y                   Y           Y    Y                     
--                                                                                                 

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
                fg = "#dacbe6",

                -- fg_dark: Inactive elements, statusline, secondary text
                fg_dark = "#dacbe6",

                -- comment: Line highlight, gutter elements, disabled states
                comment = "#ab9191",

                -- Accent colors
                -- red: Errors, diagnostics, tags, deletions, breakpoints
                red = "#f56728",

                -- orange: Constants, numbers, current line number, git modifications
                orange = "#f88416",

                -- yellow: Types, classes, constructors, warnings, numbers, booleans
                yellow = "#ffff00",


                -- green: Comments, strings, success states, git additions
                green = "#449392",

                -- cyan: Parameters, regex, preprocessor, hints, properties
                cyan = "#449392",

                -- blue: Functions, keywords, directories, links, info diagnostics
                blue = "#2976d1",

                -- purple: Storage keywords, special keywords, identifiers, namespaces
                purple = "#976add",

                -- magenta: Function declarations, exception handling, tags
                magenta = "#976add",

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

-- ░░      ░░░  ░░░░░░░░       ░░                              
-- ▒  ▒▒▒▒  ▒▒  ▒▒▒▒▒▒▒▒  ▒▒▒▒  ▒                              
-- ▓  ▓▓▓▓  ▓▓  ▓▓▓▓▓▓▓▓  ▓▓▓▓  ▓                              
-- █  ████  ██  ████████  ████  █                              
-- ██      ███        ██       ██                              
--                                                             
-- ░        ░░░      ░░░       ░░░░      ░░░       ░░░░      ░░
-- ▒▒▒▒▒▒▒  ▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒  ▒
-- ▓▓▓▓▓▓▓  ▓▓  ▓▓▓▓  ▓▓       ▓▓▓  ▓▓▓▓  ▓▓       ▓▓▓  ▓▓▓▓  ▓
-- █  ████  ██  ████  ██  ████  ██  ████  ██  ████  ██  ████  █
-- ██      ████      ███       ████      ███       ████      ██
--                                                             