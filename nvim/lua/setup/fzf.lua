local vimp = require("vimp")

require("fzf-lua").setup(
    {
        winopts = {
            height = 0.9,
            width = 0.94,
            preview = {
                layout = "flex",
                horizontal = "right:50%"
            }
        },
        grep = {
            prompt = "Rg>",
            rg_opts = "--no-heading --line-number --color=always",
            grep_opts = "-g '!pnpm-lock.yaml' -g '**/!yarn-error.log' -g '!yarn.lock'"
        },
        fzf_opts = {["--layout"] = "default", ["-i"] = ""}
    }
)

vimp.nmap({"silent"}, "<C-f>", ":FzfLua files<CR>")
-- vimp.nmap({"silent", "chord"}, "<C-g>", ":FzfLua git_files<CR>")
vimp.nmap({"silent"}, "<C-q>", ":FzfLua command_history<CR>")
vimp.nmap({"silent"}, "<C-p>", ":FzfLua grep_project<CR>")
vimp.nmap({"silent"}, "<C-b>", ":FzfLua buffers<CR>")
vimp.nmap({"silent"}, "<leader>gco", ":FzfLua git_branches<CR>")
