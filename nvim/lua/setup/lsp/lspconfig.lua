local cmp = require "cmp_nvim_lsp"

local M = {}

require("neodev").setup {}

M.lsp_flags = {
  -- This is the default in Nvim 0.7+
  debounce_text_changes = 150,
}

M.capabilities = cmp.default_capabilities(vim.lsp.protocol.make_client_capabilities())

M.capabilities.textDocument.completion.completionItem = {
  documentationFormat = { "markdown", "plaintext" },
  snippetSupport = true,
  preselectSupport = true,
  insertReplaceSupport = true,
  labelDetailsSupport = true,
  deprecatedSupport = true,
  commitCharactersSupport = true,
  tagSupport = { valueSet = { 1 } },
  resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  },
}

local function hoverFixed()
  vim.api.nvim_command "set eventignore=CursorHold"
  vim.lsp.buf.hover()
  vim.api.nvim_command 'autocmd CursorMoved <buffer> ++once set eventignore=""'
end

local signs = { WARN = "▲", HINT = "⚑", ERROR = "✘", INFO = "" }

M.on_attach = function(client, bufnr)
  vim.api.nvim_create_autocmd("CursorHold", {
    buffer = bufnr,
    callback = function()
      local opts = {
        -- focusable = true,
        focus = false,
        close_events = { "CursorMoved", "InsertEnter", "FocusLost" },
        max_width = 80,
        border = "none",
        source = "always",
        wrap = true,
        prefix = function(diagnostic, i)
          local function getPrefix(sign)
            return " " .. signs[sign] .. " "
          end

          if diagnostic.severity == vim.diagnostic.severity.ERROR then
            return getPrefix "ERROR", "DiagnosticSignError"
          elseif diagnostic.severity == vim.diagnostic.severity.WARN then
            return getPrefix "WARN", "DiagnosticSignWarn"
          elseif diagnostic.severity == vim.diagnostic.severity.HINT then
            return getPrefix "HINT", "DiagnosticSignHint"
          elseif diagnostic.severity == vim.diagnostic.severity.INFO then
            return getPrefix "INFO", "DiagnosticSignInfo"
          end
        end,
        format = function(diagnostic)
          return diagnostic.message .. " "
        end,
        scope = "cursor",
        header = "",
      }
      vim.diagnostic.open_float(nil, opts)
    end,
  }) -- Mappings.

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap = true, silent = true, buffer = bufnr }
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

-- Define LSP configurations
vim.lsp.config("emmet_ls", {
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  init_options = {
    html = {
      options = {
        ["bem.enabled"] = true,
      },
    },
  },
})

vim.lsp.config("elixirls", {
  cmd = { "/opt/homebrew/bin/elixir-ls" },
  filetypes = { "elixir", "eelixir", "heex", "surface" },
  root_markers = { "mix.exs", ".git" },
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  settings = {
    elixirLS = {
      fetchDeps = false,
    },
  },
})

local function get_tsserver_path()
  local paths = vim.fn.glob(
    vim.fn.expand "~" .. "/.asdf/installs/nodejs/*/lib/node_modules/typescript/lib/tsserver.js",
    false,
    true
  )
  if #paths > 0 then
    table.sort(paths)
    return paths[#paths]
  end
end

vim.lsp.config("ts_ls", {
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  flags = M.lsp_flags,
  init_options = {
    tsserver = {
      path = get_tsserver_path(),
    },
  },
})

vim.lsp.config("lua_ls", {
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  flags = M.lsp_flags,
  settings = {
    Lua = {
      completion = {
        callSnippet = "Replace",
      },
    },
  },
})

vim.lsp.config("sqlls", {
  cmd = { "sql-language-server", "up", "--method", "stdio" },
  filetypes = { "sql", "mysql" },
  root_markers = { ".git" },
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  flags = M.lsp_flags,
})

-- vim.lsp.config("tailwindcss", {
--   capabilities = M.capabilities,
--   on_attach = M.on_attach,
--   flags = M.lsp_flags,
--   settings = {
--     tailwindCSS = {
--       userLanguages = {
--         elixir = "html",
--         html = "html",
--         css = "css"
--       }
--     },
--   }
-- })

vim.lsp.config("pylsp", {
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  flags = M.lsp_flags,
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          enabled = true,
          ignore = { "E501", "E231" },
          maxLineLength = 120,
        },
      },
    },
  },
})

-- vim.lsp.config("eslint", {
--   capabilities = M.capabilities,
--   on_attach = M.on_attach,
--   flags = M.lsp_flags,
-- })

vim.lsp.config("dockerls", {
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  flags = M.lsp_flags,
})

vim.lsp.config("docker_compose_language_service", {
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  flags = M.lsp_flags,
})

vim.lsp.config("elp", {
  capabilities = M.capabilities,
  on_attach = M.on_attach,
  flags = M.lsp_flags,
  settings = {
    elp = {
      diagnostics = {
        disabled = {
          "W0030",
          "W0031",
          "W0032"
        }
      }
    }
  }
})

-- Enable all configured LSP servers
vim.lsp.enable("emmet_ls")
vim.lsp.enable("elixirls")
vim.lsp.enable("ts_ls")
vim.lsp.enable("lua_ls")
vim.lsp.enable("sqlls")
-- vim.lsp.enable("tailwindcss")
vim.lsp.enable("pylsp")
-- vim.lsp.enable("eslint")
vim.lsp.enable("dockerls")
vim.lsp.enable("docker_compose_language_service")
vim.lsp.enable("elp")

local sign = function(opts)
  vim.fn.sign_define(opts.name, {
    texthl = opts.name,
    text = opts.text,
    numhl = "",
  })
end

sign { name = "DiagnosticSignError", text = signs["ERROR"] }
sign { name = "DiagnosticSignWarn", text = signs["WARN"] }
sign { name = "DiagnosticSignHint", text = signs["HINT"] }
sign { name = "DiagnosticSignInfo", text = signs["INFO"] }

vim.diagnostic.config {
  virtual_text = false,
  float = {},
  signs = true,
  update_in_insert = true,
  severity_sort = true,
}
vim.cmd [[
hi DiagnosticHint guifg=#8b9898 guibg=NONE
augroup FormatAutogroup
  autocmd!
  autocmd BufWritePost * FormatWrite
augroup END
]]

  vim.g.copilot_proxy_strict_ssl = false
