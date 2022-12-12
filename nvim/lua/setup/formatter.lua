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
        elixir = {
            exe = "mix",
            args = {
                "format",
                "--"
            }
        },
        lua = {
            exe = "luafmt"
        }
    },
    function(k, v)
        return {
            function()
                local configuration = {
                    exe = v["exe"] or "prettierd",
                    args = v["args"] or {vim.api.nvim_buf_get_name(0)},
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
