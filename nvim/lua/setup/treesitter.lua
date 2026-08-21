local present, nvim_treesitter = pcall(require, "nvim-treesitter")

if not present then
  return
end

local langs = {
  "graphql",
  "lua",
  "javascript",
  "typescript",
  "tsx",
  "elixir",
  "heex",
  "eex",
  "html",
  "css",
}

nvim_treesitter.install(langs)

local ft_to_lang = {
  typescriptreact = "tsx",
  eelixir = "eex",
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "graphql",
    "lua",
    "javascript",
    "typescript",
    "typescriptreact",
    "elixir",
    "heex",
    "eelixir",
    "html",
    "css",
  },
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    local lang = ft_to_lang[ft] or ft
    if lang == "tsx" and vim.api.nvim_buf_line_count(args.buf) > 5000 then
      return
    end
    pcall(vim.treesitter.start, args.buf, lang)
    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

local ok_ctx, ctx = pcall(require, "ts_context_commentstring")
if ok_ctx then
  ctx.setup {
    enable = true,
    enable_autocmd = false,
  }
end

local ok_autotag, autotag = pcall(require, "nvim-ts-autotag")
if ok_autotag then
  autotag.setup()
end
