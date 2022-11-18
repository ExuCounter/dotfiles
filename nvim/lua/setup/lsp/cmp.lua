local cmp = require("cmp")
local compare = require("cmp.config.compare")

-- require("luasnip.loaders.from_vscode").lazy_load()

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
                    elseif luasnip.expand_or_jumpable() then
                        luasnip.expand_or_jump()
                    elseif has_words_before() then
                        cmp.complete()
                    else
                        fallback()
                    end
                end,
                {"i", "s"}
            ),
            ["<S-Tab>"] = cmp.mapping(
                function(fallback)
                    if cmp.visible() then
                        cmp.select_prev_item()
                    elseif luasnip.jumpable(-1) then
                        luasnip.jump(-1)
                    else
                        fallback()
                    end
                end,
                {"i", "s"}
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
            {name = "nvim_lsp", keyword_length = 0, priority = 14},
            {name = "nvim_lsp_signature_help", keyword_length = 1},
            -- {name = "luasnip", keyword_length = 1, priority = 13},
            -- {name = "ultisnips", keyword_length = 1, priority = 10},
            {name = "buffer", keyword_length = 2, priority = 12},
            {name = "calc", keyword_length = 2},
            {
                name = "vim-dadbod-completion",
                keyword_length = 1,
                priority = 15
            }
        }
    ),
    snippet = {
        expand = function(args)
            local luasnip = require("luasnip")
            if not luasnip then
                return
            end
            luasnip.lsp_expand(args.body)
        end
    }
}

cmp.setup(config)

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

cmp.setup.cmdline(
    ":",
    {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
            {
                {name = "buffer"}
            },
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
    -- cmp_tabnine = "[TN]",
    path = "[Path]",
    luasnip = "[SN]",
    ["vim-dadbod-completion"] = "[SQL]"
}

local kind_icons = {
    Text = "",
    Method = "",
    Function = "",
    Constructor = "",
    Field = "",
    Variable = "",
    Class = "ﴯ",
    Interface = "",
    Module = "",
    Property = "ﰠ",
    Unit = "",
    Value = "",
    Enum = "",
    Keyword = "",
    Snippet = "",
    Color = "",
    File = "",
    Reference = "",
    Folder = "",
    EnumMember = "",
    Constant = "",
    Struct = "",
    Event = "",
    Operator = "",
    TypeParameter = ""
}

cmp.setup(
    {
        formatting = {
            format = lspkind.cmp_format(
                {
                    mode = "symbol_text", -- options: 'text', 'text_symbol', 'symbol_text', 'symbol'
                    maxwidth = 40,
                    before = function(entry, vim_item)
                        vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind], vim_item.kind)

                        local menu = source_mapping[entry.source.name]
                        -- if entry.source.name == "cmp_tabnine" then
                        --     if entry.completion_item.data ~= nil and entry.completion_item.data.detail ~= nil then
                        --         menu = entry.completion_item.data.detail .. " " .. menu
                        --     end
                        -- end

                        vim_item.menu = menu

                        return vim_item
                    end
                }
            )
        }
    }
)
