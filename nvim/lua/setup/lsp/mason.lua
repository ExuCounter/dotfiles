local mason = require("mason")
local mason_lspconfig = require("mason-lspconfig")

mason.setup()
mason_lspconfig.setup(
    {
        ensure_installed = {
            "tsserver",
            "lua_ls",
            "elixirls",
            "cssls",
            "marksman",
            "html",
            "eslint",
            "tailwindcss"
        },
        automatic_installation = true
    }
)
