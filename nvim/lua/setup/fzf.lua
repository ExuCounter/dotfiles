local vimp = require("vimp")

require("fzf-lua").setup(
    {
        winopts = {
            height = 0.5,
            width = 1,
            row = 0.9,
            col = 1,
            border = {"─", "─", "─", "│", "─", "─", "─", " "},
            preview = {
                layout = "horizontal",
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
