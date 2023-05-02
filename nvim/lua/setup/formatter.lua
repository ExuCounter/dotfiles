local present, formatter = pcall(require, "formatter")
local formatter_filetypes = require "formatter.filetypes"

if not present then
    return
end

local prettierd_formatter = formatter_filetypes.javascript.prettierd
local elixir_formatter = formatter_filetypes.elixir.mixformat
local lua_formatter = formatter_filetypes.lua.luafmt

local filetype = {
    typescriptreact = {prettierd_formatter},
    typescript = {prettierd_formatter},
    javascript = {prettierd_formatter},
    json = {prettierd_formatter},
    css = {prettierd_formatter},
    scss = {prettierd_formatter},
    html = {prettierd_formatter},
    less = {prettierd_formatter},
    graphql = {prettierd_formatter},
    gql = {prettierd_formatter},
    elixir = {
        elixir_formatter
    },
    lua = {
        lua_formatter
    }
}

formatter.setup(
    {
        logging = false,
        filetype = filetype
    }
)
