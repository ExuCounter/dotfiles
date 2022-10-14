local cmp = require("cmp")
local compare = require("cmp.config.compare")

local config = {
    enabled = true,
    buffer = false,
    sorting = {
        priority_weight = 2,
        comparators = {
            compare.locality,
            compare.recently_used,
            compare.score, -- based on :  score = score + ((#sources - (source_index - 1)) * sorting.priority_weight)
            compare.offset,
            compare.order
        }
    },
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
    experimental = {
        ghost_text = true
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
            ["jj"] = function(fallback)
                require("cmp").close()
                require("cmp").abort()
                fallback()
            end,
            ["<Esc>"] = function(fallback)
                require("cmp").close()
                require("cmp").abort()
                fallback()
            end,
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<CR>"] = cmp.mapping.confirm({select = false}) -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
        }
    ),
    sources = cmp.config.sources(
        {
            {name = "cmp_tabnine", keyword_length = 3, priority = 11},
            {name = "nvim_lsp", keyword_length = 1, priority = 13},
            {name = "ultisnips", keyword_length = 1, priority = 10},
            {name = "buffer", keyword_length = 2, priority = 12}
        }
    )
}

cmp.setup(config)

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

local lspkind = require("lspkind")

local source_mapping = {
    buffer = "[Buffer]",
    nvim_lsp = "[LSP]",
    nvim_lua = "[Lua]",
    cmp_tabnine = "[TN]",
    path = "[Path]"
}

cmp.setup(
    {
        formatting = {
            -- format = lspkind.cmp_format(
            --     {
            --         -- mode = "symbol", -- show only symbol annotations
            --         maxwidth = 20, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
            --         -- The function below will be called before any actual modifications from lspkind
            --         -- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
            --         before = function(entry, vim_item)
            --             return vim_item
            --         end
            --     }
            -- ),
            format = lspkind.cmp_format(
                {
                    mode = "symbol_text", -- options: 'text', 'text_symbol', 'symbol_text', 'symbol'
                    maxwidth = 40, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
                    -- The function below will be called before any actual modifications from lspkind
                    -- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
                    before = function(entry, vim_item)
                        vim_item.kind = lspkind.presets.default[vim_item.kind]

                        local menu = source_mapping[entry.source.name]
                        if entry.source.name == "cmp_tabnine" then
                            if entry.completion_item.data ~= nil and entry.completion_item.data.detail ~= nil then
                                menu = entry.completion_item.data.detail .. " " .. menu
                            end
                            vim_item.kind = ""
                        end

                        vim_item.menu = menu

                        return vim_item
                    end
                }
            )
        }
    }
)
