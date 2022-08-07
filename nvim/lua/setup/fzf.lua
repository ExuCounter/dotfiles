local vimp = require("vimp")

require("fzf-lua").setup(
    {
        winopts = {height = 0.9, width = 0.94},
        grep = {
            prompt = "Rg>",
            rg_opts = "--no-heading --line-number --color=always",
            grep_opts = "-g '!pnpm-lock.yaml' -g '**/!yarn-error.log' -g '!yarn.lock'"
        },
        fzf_opts = {["--layout"] = "reverse-list", ["-i"] = ""}
    }
)

vimp.nmap({"silent"}, "<C-f>", ":FzfLua files<CR>")
vimp.nmap({"silent"}, "<C-p>", ":FzfLua live_grep<CR>")
