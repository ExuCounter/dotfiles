local present, lualine = pcall(require, "lualine")

if not present then
    return
end

lualine.setup {
    options = {
        theme = "solarized_light",
        disabled_filetypes = {
            "alpha"
        },
        ignore_focus = {"NvimTree"}
    },
    extensions = {"nvim-tree"},
    sections = {
        lualine_a = {"mode"},
        lualine_b = {
            "branch",
            {"diff"}
        },
        lualine_c = {{"filename", path = 1}},
        lualine_x = {
            {
                "diagnostics",
                color = {bg = "#eee8d5"},
                symbols = {
                    warn = "▲ ",
                    hint = "⚑ ",
                    error = "✘ ",
                    info = " "
                }
            },
            "encoding",
            "fileformat",
            "filetype"
        },
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
