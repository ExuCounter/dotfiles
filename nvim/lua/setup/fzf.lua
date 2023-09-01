local present, fzfLua = pcall(require, "fzf-lua")

if not present then
  return
end

local actions = require "fzf-lua.actions"

local fzf_actions = {
  ["ctrl-w"] = actions.file_vsplit,
  ["ctrl-s"] = actions.file_split,
  ["ctrl-v"] = actions.file_vsplit,
  ["default"] = actions.file_edit_or_qf,
  ["ctrl-]"] = actions.file_sel_to_qf,
}

respect_gitignore = true

vim.api.nvim_create_user_command("ToggleDisrespectGitIgnore", function()
  respect_gitignore = not respect_gitignore
end, {})

local rg_flag = function()
  if respect_gitignore then
    return ""
  else
    return "-u"
  end
end

fzfLua.setup {
  winopts = {
    height = 0.5,
    width = 1,
    row = 0.9,
    col = 1,
    border = { "─", "─", "─", "│", "─", "─", "─", " " },
    preview = {
      layout = "horizontal",
      horizontal = "right:50%",
    },
  },
  grep = {
    prompt = "Rg>",
    rg_opts = "--smart-case --no-heading --line-number --color=always -g '!pnpm-lock.yaml' -g '!yarn-error.log' -g '!yarn.lock' -g '!dotbot/' ",
    rg_glob = true,
  },
  files = {
    rg_opts = "--color=never --files --hidden --follow -g '!.git' -g '!dotbot/' " .. rg_flag(),
  },
  actions = {
    live_grep = fzf_actions,
    files = fzf_actions,
    buffers = fzf_actions,
    registers = {
      ["default"] = actions.paste_register,
    },
  },
  fzf_opts = { ["--layout"] = "default", ["-i"] = "", ["--keep-right"] = "" },
}
