local lspconfig = require("lspconfig")
local cmp = require("cmp_nvim_lsp")

local M = {}

require("neodev").setup({})

M.lsp_flags = {
    -- This is the default in Nvim 0.7+
    debounce_text_changes = 150
}

M.capabilities = cmp.default_capabilities(vim.lsp.protocol.make_client_capabilities())

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
                    -- focusable = true,
                    focus = false,
                    close_events = {"CursorMoved", "InsertEnter", "FocusLost"},
                    max_width = 80,
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
    vim.keymap.set("n", "gv", ":vsplit | lua vim.lsp.buf.definition()<CR>")
    vim.keymap.set("n", "gs", ":split | lua vim.lsp.buf.definition()<CR>")
    vim.keymap.set("n", "K", hoverFixed, bufopts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, bufopts)
    vim.keymap.set("n", "<space>ca", vim.lsp.buf.code_action, bufopts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
end

lspconfig.emmet_ls.setup(
    {
        on_attach = M.on_attach,
        capabilities = M.capabilities,
        filetypes = {"html", "css", "sass", "scss", "less"},
        init_options = {
            html = {
                options = {
                    ["bem.enabled"] = true
                }
            }
        }
    }
)

lspconfig.tailwindcss.setup(
    {
        on_attach = M.on_attach,
        flags = M.lsp_flags,
        capabilities = M.capabilities
    }
)

lspconfig.elixirls.setup(
    {
        on_attach = M.on_attach,
        flags = M.lsp_flags,
        capabilities = M.capabilities
    }
)

lspconfig.tsserver.setup(
    {
        on_attach = M.on_attach,
        flags = M.lsp_flags,
        capabilities = M.capabilities
    }
)

lspconfig.lua_ls.setup(
    {
        on_attach = M.on_attach,
        flags = M.lsp_flags,
        capabilities = M.capabilities,
        settings = {
            Lua = {
                completion = {
                    callSnippet = "Replace"
                }
            }
        }
    }
)

local function diffConflict(view)
    local currentBufferNumber = 0
    local bufferLines = vim.api.nvim_buf_get_lines(currentBufferNumber, 0, -1, true)
    local currentPos = vim.api.nvim_win_get_cursor(currentBufferNumber)[1]
    local headPositions = {}
    local theirPositions = {}
    local parentStartPositions = {}
    local parentEndPositions = {}

    local identifiers = {head = "<<<<<<<", parentStart = "|||||||", parentEnd = "=======", their = ">>>>>>>"}

    for i = 1, table.getn(bufferLines) do
        local line = bufferLines[i]

        if string.find(line, identifiers.head) then
            table.insert(headPositions, i)
        end
        if string.find(line, identifiers.parentStart) then
            table.insert(parentStartPositions, i)
        end
        if string.find(line, identifiers.parentEnd) then
            table.insert(parentEndPositions, i)
        end
        if string.find(line, identifiers.their) then
            table.insert(theirPositions, i)
        end
    end

    local conflicts = {}
    local current_conflict = nil

    for i = 1, table.getn(headPositions) do
        local headPos = headPositions[i]
        local parentStartPos = parentStartPositions[i]
        local parentEndPos = parentEndPositions[i]
        local theirPos = theirPositions[i]

        local conflict = {
            headPos = headPos,
            parentStartPos = parentStartPos,
            parentEndPos = parentEndPos,
            theirPos = theirPos
        }

        table.insert(conflicts, conflict)

        if currentPos >= headPos and currentPos <= theirPos then
            current_conflict = conflict
        end
    end

    if current_conflict then
        local headLines =
            vim.api.nvim_buf_get_lines(
            currentBufferNumber,
            current_conflict.headPos,
            current_conflict.parentStartPos - 1,
            true
        )
        local parentLines =
            vim.api.nvim_buf_get_lines(
            currentBufferNumber,
            current_conflict.parentStartPos,
            current_conflict.parentEndPos - 1,
            true
        )
        local theirLines =
            vim.api.nvim_buf_get_lines(
            currentBufferNumber,
            current_conflict.parentEndPos,
            current_conflict.theirPos - 1,
            true
        )

        vim.cmd("enew")

        local function setLinesToCurrentBuffer(lines)
            vim.api.nvim_buf_set_lines(currentBufferNumber, 0, 0, true, lines)
        end

        if view == "head-their" then
            setLinesToCurrentBuffer(headLines)
        elseif view == "head-parent" then
            setLinesToCurrentBuffer(headLines)
        elseif view == "parent-their" then
            setLinesToCurrentBuffer(parentLines)
        end

        vim.cmd("vnew")

        if view == "head-their" then
            setLinesToCurrentBuffer(theirLines)
        elseif view == "head-parent" then
            setLinesToCurrentBuffer(parentLines)
        elseif view == "parent-their" then
            setLinesToCurrentBuffer(parentLines)
        end

        vim.cmd("windo diffthis")
    else
        print("Conflict under cursor not found")
    end
end

vim.api.nvim_create_user_command(
    "DiffHeadTheir",
    function()
        diffConflict("head-their")
    end,
    {}
)
vim.api.nvim_create_user_command(
    "DiffHeadParent",
    function()
        diffConflict("head-parent")
    end,
    {}
)
vim.api.nvim_create_user_command(
    "DiffParentTheir",
    function()
        diffConflict("parent-their")
    end,
    {}
)

vim.keymap.set("n", "<leader>J", ":DiffHeadTheir<CR>", {})
vim.keymap.set("n", "<leader>K", ":DiffHeadParent<CR>", {})
vim.keymap.set("n", "<leader>L", ":DiffParentTheir<CR>", {})

lspconfig.sqlls.setup(
    {
        on_attach = M.on_attach,
        flags = M.lsp_flags,
        capabilities = M.capabilities
    }
)

lspconfig.eslint.setup(
    {
        on_attach = M.on_attach,
        flags = M.lsp_flags,
        capabilities = M.capabilities
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
  autocmd BufWritePost * Format
augroup END
]]
)
