local vimp = require("vimp")
local actions = require "fzf-lua.actions"

local fzf_actions = {
    ["ctrl-w"] = actions.file_vsplit,
    ["ctrl-s"] = actions.file_split,
    ["ctrl-v"] = actions.file_vsplit
}

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
            rg_opts = "--smart-case --no-heading --line-number --color=always -g '!pnpm-lock.yaml' -g '!yarn-error.log' -g '!yarn.lock' "
        },
        actions = {
            live_grep = fzf_actions,
            files = fzf_actions,
            buffers = fzf_actions
        },
        fzf_opts = {["--layout"] = "default", ["-i"] = "", ["--keep-right"] = ""}
    }
)
