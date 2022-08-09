local mason = require("mason")
local mason_lspconfig = require("mason-lspconfig")

mason.setup()
mason_lspconfig.setup(
    {
        ensure_installed = {
            "tsserver",
            "sumneko_lua",
            "elixirls",
            "cssls",
            "sqls",
            "marksman",
            "html",
            "eslint"
        },
        automatic_installation = true
    }
)
