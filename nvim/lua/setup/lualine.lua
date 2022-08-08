local lualine = require("lualine")

lualine.setup {
    options = {
        theme = "solarized_light",
        disabled_filetypes = {
            "NvimTree"
        }
    },
    sections = {
        lualine_a = {"mode"},
        lualine_b = {
            "branch",
            {"diff", color = {bg = "#eee8d5"}},
            {
                "diagnostics",
                color = {bg = "#eee8d5"},
                symbols = {},
                signs = {warn = "▲", hint = "⚑", error = "✘", info = ""}
            }
        },
        lualine_c = {"filename"},
        lualine_x = {"encoding", "fileformat", "filetype"},
        lualine_z = {}
    },
    inactive_sections = {
        lualine_a = {"filename"},
        lualine_b = {},
        lualine_c = {},
        lualine_x = {"encoding", "fileformat", "filetype"},
        lualine_y = {},
        lualine_z = {}
    }
}
