local vimp = require("vimp")

require("fzf-lua").setup({})

vimp.nmap({ "silent" }, "<C-p>", ":FzfLua files<CR>")
vimp.noremap({ "silent" }, "<C-f>", ":FzfLua files<CR>")

