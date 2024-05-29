local present, formatter = pcall(require, "formatter")
local formatter_filetypes = require "formatter.filetypes"

if not present then
  return
end

local prettierd_formatter = formatter_filetypes.javascript.prettierd
local elixir_formatter = formatter_filetypes.elixir.mixformat
local python_formatter = formatter_filetypes.python.autopep8
local lua_formatter = formatter_filetypes.lua.stylua

local filetype = {
  typescriptreact = { prettierd_formatter },
  typescript = { prettierd_formatter },
  javascript = { prettierd_formatter },
  json = { prettierd_formatter },
  css = { prettierd_formatter },
  scss = { prettierd_formatter },
  html = { prettierd_formatter },
  less = { prettierd_formatter },
  graphql = { prettierd_formatter },
  gql = { prettierd_formatter },
  elixir = {
    elixir_formatter,
  },
  lua = {
    lua_formatter,
  },
}

-- python = {
--   function()
--     return {
--       exe = "black",
--       args = {
--         "-l",
--         120,
--         "-S",
--         "-C",
--         "-q",
--         "--stdin-filename",
--         vim.fn.fnameescape(vim.api.nvim_buf_get_name(0)),
--         "-",
--       },
--       stdin = true,
--     }
--   end,
-- },

formatter.setup {
  logging = false,
  filetype = filetype,
}
