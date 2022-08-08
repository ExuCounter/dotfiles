local lspconfig = require("lspconfig")
local cmp = require("cmp_nvim_lsp")

local M = {}

M.lsp_flags = {
    -- This is the default in Nvim 0.7+
    debounce_text_changes = 150
}

M.capabilities = cmp.update_capabilities(vim.lsp.protocol.make_client_capabilities())

M.capabilities.textDocument.completion.completionItem = {
    documentationFormat = {"markdown", "plaintext"},
    snippetSupport = true,
    preselectSupport = true,
    insertReplaceSupport = true,
    labelDetailsSupport = true,
    deprecatedSupport = true,
    commitCharactersSupport = true,
    tagSupport = {valueSet = {1}},
    resolveSupport = {
        properties = {
            "documentation",
            "detail",
            "additionalTextEdits"
        }
    }
}

local function hoverFixed()
    vim.api.nvim_command("set eventignore=CursorHold")
    vim.lsp.buf.hover()
    vim.api.nvim_command('autocmd CursorMoved <buffer> ++once set eventignore=""')
end

local signs = {WARN = "▲", HINT = "⚑", ERROR = "✘", INFO = ""}

M.on_attach = function(client, bufnr)
    vim.api.nvim_create_autocmd(
        "CursorHold",
        {
            buffer = bufnr,
            callback = function()
                local opts = {
                    focusable = false,
                    close_events = {"BufLeave", "CursorMoved", "InsertEnter", "FocusLost"},
                    border = "none",
                    source = "always",
                    wrap = true,
                    prefix = function(diagnostic, i)
                        local function getPrefix(sign)
                            return " " .. signs[sign] .. " "
                        end

                        if diagnostic.severity == vim.diagnostic.severity.ERROR then
                            return getPrefix("ERROR"), "DiagnosticSignError"
                        elseif diagnostic.severity == vim.diagnostic.severity.WARN then
                            return getPrefix("WARN"), "DiagnosticSignWarn"
                        elseif diagnostic.severity == vim.diagnostic.severity.HINT then
                            return getPrefix("HINT"), "DiagnosticSignHint"
                        elseif diagnostic.severity == vim.diagnostic.severity.INFO then
                            return getPrefix("INFO"), "DiagnosticSignInfo"
                        end
                    end,
                    format = function(diagnostic)
                        return diagnostic.message .. " "
                    end,
                    scope = "cursor",
                    header = ""
                }
                vim.diagnostic.open_float(nil, opts)
            end
        }
    ) -- Mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local bufopts = {noremap = true, silent = true, buffer = bufnr}
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
    vim.keymap.set("n", "K", hoverFixed, bufopts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, bufopts)
    vim.keymap.set("n", "<space>ca", vim.lsp.buf.code_action, bufopts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
end

lspconfig.tsserver.setup(
    {
        on_attach = M.on_attach,
        flags = M.lsp_flags,
        capabilities = M.capabilities
    }
)

lspconfig.sumneko_lua.setup(
    {
        on_attach = M.on_attach,
        flags = M.lsp_flags,
        capabilities = M.capabilities
    }
)

lspconfig.emmet_ls.setup(
    {
        on_attach = M.on_attach,
        capabilities = M.capabilities,
        filetypes = {
            "html",
            "css",
            "sass",
            "scss",
            "less",
            "javascript",
            "typescript",
            "typescriptreact"
        },
        init_options = {
            html = {
                options = {
                    ["bem.enabled"] = true
                }
            }
        }
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

sign({name = "DiagnosticSignError", text = signs["ERROR"]})
sign({name = "DiagnosticSignWarn", text = signs["WARN"]})
sign({name = "DiagnosticSignHint", text = signs["HINT"]})
sign({name = "DiagnosticSignInfo", text = signs["INFO"]})

vim.diagnostic.config(
    {
        virtual_text = false,
        float = {},
        signs = true,
        update_in_insert = true,
        severity_sort = true
    }
)
vim.cmd(
    [[
hi DiagnosticHint guifg=#8b9898 guibg=NONE
augroup FormatAutogroup
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END
]]
)

vimp.nnoremap({"silent"}, "cn", "<cmd>lua vim.diagnostic.goto_next()<CR>")
vimp.nnoremap({"silent"}, "cN", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
