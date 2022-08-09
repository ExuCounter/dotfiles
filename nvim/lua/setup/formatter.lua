local formatter = require("formatter")

local function map(tbl, f)
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