local utils = require("setup/utils")
local bufferline = require("bufferline")

vim.opt.termguicolors = true

local opts = {silent = true}

utils.map("n", "<leader>1", "<cmd> lua require('bufferline').go_to_buffer(1, true)<cr>", opts)
utils.map("n", "<leader>2", "<cmd> lua require('bufferline').go_to_buffer(2, true)<cr>", opts)
utils.map("n", "<leader>3", "<cmd> lua require('bufferline').go_to_buffer(3, true)<cr>", opts)
utils.map("n", "<leader>4", "<cmd> lua require('bufferline').go_to_buffer(4, true)<cr>", opts)
utils.map("n", "<leader>5", "<cmd> lua require('bufferline').go_to_buffer(5, true)<cr>", opts)
utils.map("n", "<leader>6", "<cmd> lua require('bufferline').go_to_buffer(6, true)<cr>", opts)
utils.map("n", "<leader>7", "<cmd> lua require('bufferline').go_to_buffer(7, true)<cr>", opts)
utils.map("n", "<leader>8", "<cmd> lua require('bufferline').go_to_buffer(8, true)<cr>", opts)
utils.map("n", "<leader>9", "<cmd> lua require('bufferline').go_to_buffer(9, true)<cr>", opts)

bufferline.setup(
    {
        options = {
            mode = "buffers",
            diagnostics = "none",
            show_buffer_close_icons = false,
            show_close_icon = false,
            indicator_icon = "|",
            tab_size = 15,
            filetype_exclude = {"dashboard", "lsp-installer", "help"},
            buftype_exclude = {"terminal"}
        },
        highlights = {
            indicator_selected = {
                guifg = "#cb4b16"
            }
        }
    }
)
