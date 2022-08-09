local vimp = require("vimp")
local utils = require("setup/utils")

utils.map("n", "<leader>v", ":vnew %<cr>")
utils.map("n", "<leader>ev", ":vnew <cr>")
utils.map("n", "<leader>s", ":new %<cr>")

utils.map("n", "<leader>l", ":bn <cr>")
utils.map("n", "<leader>h", ":bp <cr>")
