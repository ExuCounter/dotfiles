require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true,              -- false will disable the whole extensio
    additional_vim_regex_highlighting = false,
  },
  indent = {
    enable = true
  },
  autotag = {
    enable = true,
  },
  context_commentstring = {
    enable = true,
    enable_autocmd = false
  },
  rainbow = {
    enable = false,
    -- disable = { "jsx", "cpp" }, list of languages you want to disable the plugin for
    -- extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
    max_file_lines = nil, -- Do not enable for files with more than n lines, int
		colors = {
			"#e5c07b",
			"#dcdfe4",
			"#7d8dad",
			"#56b6c2",
			"#98c379",
			"#61afef",
		}, -- table of hex strings
    -- termcolors = {} -- table of colour name strings
  }
}
