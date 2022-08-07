local vimp = require("vimp")
local cmp = require("cmp")
local formatter = require("formatter")
local lsp_config = require("lspconfig")
local opts = {noremap = true, silent = true}
vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, opts)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
local on_attach = function(client, bufnr)
    -- Enable completion triggered by <c-x><c-o>
    -- vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
    -- require "lsp_signature".on_attach(
    --     {
    --         bind = true, -- This is mandatory, otherwise border config won't get registered.
    --         handler_opts = {
    --             border = "none" -- double, rounded, single, shadow, none
    --         },
    --         floating_window_above_cur_line = false,
    --         floating_window = false,
    --         wrap = true
    --     },
    --     bufnr
    -- )
    -- Mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local bufopts = {noremap = true, silent = true, buffer = bufnr}
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
    vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
    vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
    vim.keymap.set(
        "n",
        "<space>wl",
        function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end,
        bufopts
    )
    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, bufopts)
    vim.keymap.set("n", "<space>ca", vim.lsp.buf.code_action, bufopts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
end

local lsp_flags = {
    -- This is the default in Nvim 0.7+
    debounce_text_changes = 150
}

cmp.setup(
    {
        snippet = {
            -- REQUIRED - you must specify a snippet engine
            expand = function(args)
                vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
            end
        },
        window = {
            completion = {
                bordered = false
            },
            documentation = {
                bordered = false
            }
        },
        mapping = cmp.mapping.preset.insert(
            {
                ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                ["<C-f>"] = cmp.mapping.scroll_docs(4),
                ["<Tab>"] = cmp.mapping(
                    function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                            return
                        end
                        fallback()
                    end,
                    {"i", "c"}
                ),
                ["<S-Tab>"] = cmp.mapping(
                    function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                            return
                        end
                        fallback()
                    end,
                    {"i", "c"}
                ),
                ["<C-Space>"] = cmp.mapping.complete(),
                ["<CR>"] = cmp.mapping.confirm({select = true}) -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
            }
        ),
        sources = cmp.config.sources(
            {
                {name = "nvim_lsp"}
                -- {name = "nvim_lsp_signature_help"}
                -- { name = "vsnip" }, -- For vsnip users.
                -- { name = 'luasnip' }, -- For luasnip users.
                -- { name = 'ultisnips' }, -- For ultisnips users.
                -- { name = 'snippy' }, -- For snippy users.
            },
            {
                {name = "buffer"}
            }
        )
    }
)
-- Set configuration for specific filetype.
cmp.setup.filetype(
    "gitcommit",
    {
        sources = cmp.config.sources(
            {
                {name = "cmp_git"} -- You can specify the `cmp_git` source if you were installed it.
            },
            {
                {name = "buffer"}
            }
        )
    }
)
-- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(
    "/",
    {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
            {name = "buffer"}
        }
    }
)
-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(
    ":",
    {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
            {
                {name = "path"}
            },
            {
                {name = "cmdline"}
            }
        )
    }
)
-- Setup lspconfig.
local capabilities = require("cmp_nvim_lsp").update_capabilities(vim.lsp.protocol.make_client_capabilities())
local lspkind = require("lspkind")
cmp.setup(
    {
        formatting = {
            format = lspkind.cmp_format(
                {
                    -- mode = "symbol", -- show only symbol annotations
                    maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
                    -- The function below will be called before any actual modifications from lspkind
                    -- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
                    before = function(entry, vim_item)
                        print(entry)
                        return vim_item
                    end
                }
            )
        }
    }
)
require("mason").setup()
require("mason-lspconfig").setup(
    {
        ensure_installed = {
            "tsserver",
            "sumneko_lua",
            "eslint",
            "elixirls",
            "cssls",
            "sqls",
            "marksman",
            "html"
        },
        automatic_installation = true
    }
)
lsp_config.tsserver.setup(
    {
        on_attach = on_attach,
        flags = lsp_flags,
        capabilities = capabilities
    }
)
lsp_config.eslint.setup(
    {
        on_attach = on_attach,
        flags = lsp_flags,
        capabilities = capabilities
    }
)
lsp_config.sumneko_lua.setup(
    {
        on_attach = on_attach,
        flags = lsp_flags,
        capabilities = capabilities
    }
)
local sign = function(opts)
    vim.fn.sign_define(
        opts.name,
        {
            texthl = opts.name,
            text = opts.text,
            numhl = ""
        }
    )
end
sign({name = "DiagnosticSignError", text = "✘"})
sign({name = "DiagnosticSignWarn", text = "▲"})
sign({name = "DiagnosticSignHint", text = "⚑"})
sign({name = "DiagnosticSignInfo", text = ""})
vim.diagnostic.config(
    {
        virtual_text = false,
        -- severity_sort = true,
        float = {},
        signs = true
        -- format = lspkind.cmp_format({
        -- 	mode = "symbol", -- show only symbol annotations
        -- 	maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
        -- 	-- The function below will be called before any actual modifications from lspkind
        -- 	-- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
        -- 	before = function(entry, vim_item)
        -- 		print(vim_item)
        -- 		return entry
        -- 	end,
        -- }),
    }
)
vim.cmd(
    [[
autocmd CursorHold * lua vim.diagnostic.open_float({width = 80})
hi DiagnosticHint guifg=Blue guibg=NONE
" autocmd CursorHoldI * silent! lua vim.lsp.buf.signature_help()
augroup FormatAutogroup
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END
]]
)
vimp.nnoremap({"silent"}, "cn", "<cmd>lua vim.diagnostic.goto_next()<CR>")
vimp.nnoremap({"silent"}, "cN", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
--
function map(tbl, f)
    local t = {}
    for k, v in pairs(tbl) do
        t[k] = f(k, v)
    end
    return t
end
local formatter_filetype =
    map(
    {
        typescriptreact = {},
        typescript = {},
        javascript = {},
        json = {},
        css = {},
        scss = {},
        html = {},
        less = {},
        lua = {
            exe = "luafmt"
        }
    },
    function(k, v)
        return {
            function()
                local configuration = {
                    exe = v["exe"] or "prettierd",
                    args = {vim.api.nvim_buf_get_name(0)},
                    stdin = true
                }
                return configuration
            end
        }
    end
)
formatter.setup(
    {
        logging = false,
        filetype = formatter_filetype
    }
)
capabilities.textDocument.completion.completionItem.snippetSupport = true
lsp_config.emmet_ls.setup(
    {
        on_attach = on_attach,
        capabilities = capabilities,
        filetypes = {"html", "css", "sass", "scss", "less"},
        init_options = {
            html = {
                options = {
                    -- For possible options, see: https://github.com/emmetio/emmet/blob/master/src/config.ts#L79-L267
                    ["bem.enabled"] = true
                }
            }
        }
    }
)
