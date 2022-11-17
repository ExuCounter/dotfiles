local actions = require "fzf-lua.actions"

local fzf_actions = {
    ["ctrl-w"] = actions.file_vsplit,
    ["ctrl-s"] = actions.file_split,
    ["ctrl-v"] = actions.file_vsplit,
    ["default"] = actions.file_edit_or_qf
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
            rg_opts = "--smart-case --no-heading --line-number --color=always -g '!pnpm-lock.yaml' -g '!yarn-error.log' -g '!yarn.lock' -g '!dotbot/' "
        },
        files = {
            rg_opts = "--color=never --files --hidden --follow -g '!.git' -g '!dotbot/' "
        },
        actions = {
            live_grep = fzf_actions,
            files = fzf_actions,
            buffers = fzf_actions,
            registers = {
                ["default"] = actions.paste_register
            }
        },
        fzf_opts = {["--layout"] = "default", ["-i"] = "", ["--keep-right"] = ""}
    }
)
