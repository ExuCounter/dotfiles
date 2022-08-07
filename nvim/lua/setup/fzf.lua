local vimp = require("vimp")

require("fzf-lua").setup(
    {
        winopts = {
            height = 0.9,
            width = 0.94,
            preview = {
                layout = "vertical"
            }
        },
        grep = {
            prompt = "Rg>",
            rg_opts = "--no-heading --line-number --color=always",
            grep_opts = "-g '!pnpm-lock.yaml' -g '**/!yarn-error.log' -g '!yarn.lock'"
        },
        fzf_opts = {["--inline-info"] = "", ["-i"] = "", ["--exact"] = nil}
    }
)

vimp.nmap({"silent"}, "<C-f>", ":FzfLua files<CR>")
vimp.nmap({"silent"}, "<C-p>", ":FzfLua grep_project<CR>")
vimp.nmap({"silent"}, "<leader>gco", ":FzfLua git_branches<CR>")
