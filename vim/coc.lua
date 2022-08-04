local vimp = require("vimp")

local opts = { noremap=true, silent=true }

vim.g.coc_global_extensions = {
	"coc-tsserver",
	"coc-css",
	"coc-emmet",
	"coc-html",
	"coc-eslint",
	"coc-tabnine",
	"coc-prettier",
	"coc-react-refactor",
	"coc-snippets",
	"coc-styled-components",
	"coc-elixir",
	"coc-elixir",
}

vimp.nmap("<leader>do", "<Plug>(coc-codeaction)")
vimp.nmap("<leader>rn", "<Plug>(coc-rename)")

-- Use <C-j> for jump to next placeholder, it's default of coc.nvim
vim.g.coc_snippet_next = "<c-l>"

-- Use <C-k> for jump to previous placeholder, it's default of coc.nvim
vim.g.coc_snippet_prev = "<c-h>"

-- vimp.nnoremap({ "silent" }, "K", ":call <SID>show_documentation()<CR>")

