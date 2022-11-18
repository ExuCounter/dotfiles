local present, formatter = pcall(require, "formatter")

if not present then
    return
end

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
        graphql = {},
        gql = {},
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
                    stdin = true,
                    try_node_modules = true
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
