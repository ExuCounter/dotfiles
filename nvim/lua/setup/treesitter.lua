local present, treesitter = pcall(require, "nvim-treesitter.configs")

if not present then
  return
end

local function ts_disable(lang, bufnr)
  return vim.api.nvim_buf_line_count(bufnr) > 5000 and lang == "tsx"
end

treesitter.setup {
  ensure_installed = { "graphql", "lua", "javascript", "typescript", "elixir", "html", "css", "heex", "eex", "tsx" }, -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true, -- false will disable the whole extensio
    disable = function(lang, bufnr)
      return ts_disable(lang, bufnr)
    end,
    use_languagetree = true,
  },
  indent = { enable = true },
  autotag = {
    enable = true,
  },
  context_commentstring = {
    enable = true,
    enable_autocmd = false,
  },
}
