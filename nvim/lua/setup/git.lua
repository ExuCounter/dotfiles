local vimp = require("vimp")
local getBranch = vim.fn["gitbranch#name"]
local utils = require("setup/utils")

-- Git windows shortcuts
vimp.nnoremap("<leader>gcm", ":Git commit -v -q <CR>")
vimp.nnoremap("<leader>gd", ":Git diff")
vimp.nnoremap("<leader>gcl", ":Gclog -50<CR>")
vimp.nnoremap("<leader>gl", ":Git log -50<CR>")
vimp.nnoremap("<C-g>", ":GFiles?<cr>")
vimp.nnoremap({"chord", "silent"}, "<leader>g", ":Git<cr>")
vimp.nnoremap({"silent"}, "<leader>G", ":Git<cr>")

-- Git push/pull/fetch shortcuts
vimp.nnoremap({"chord"}, "<Leader>gbp", ":Git -c push.default=current push<CR>")
vimp.nnoremap("<Leader>gpf", ":Git -c push.default=current push --force<CR>")
vimp.nnoremap("<Leader>gpl", ":Git pull origin " .. getBranch() .. "<CR>")
vimp.nnoremap("<Leader>gfa", ":Git fetch --all<CR>")

-- Git rebase/blame/checkout/reset shortcuts
vimp.nnoremap("<Leader>grc", ":Git rebase --continue<CR>")
vimp.nnoremap("<Leader>gra", ":Git rebase --abort")
vimp.nnoremap("<Leader>grsh", ":Git reset --hard")
vimp.nnoremap("<Leader>gri", ":Git rebase --interactive HEAD~")
vimp.nnoremap("<Leader>gcb", ":Git checkout -b")
vimp.nnoremap("<Leader>gbl", ":Git blame -et<CR>")

-- Disable the default highlight group
vim.g.conflict_marker_highlight_group = ""

-- Include text after begin and end markers
vim.g.conflict_marker_begin = "^<<<<<<< .*$"
vim.g.conflict_marker_common_ancestors = "^||||||| .*$"
vim.g.conflict_marker_separator = "^=======$"
vim.g.conflict_marker_end = "^>>>>>>> .*$"

require("gitsigns").setup {
    signs = {
        add = {hl = "GitSignsAdd", text = "+", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn"},
        change = {hl = "GitSignsChange", text = "│", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn"},
        delete = {hl = "GitSignsDelete", text = "_", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn"},
        topdelete = {hl = "GitSignsDelete", text = "‾", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn"},
        changedelete = {hl = "GitSignsChange", text = "~", numhl = "GitSignsChangeNr", linehl = "GitSignsCh1angeLn"}
    },
    current_line_blame = true,
    sign_priority = 6,
    on_attach = function(bufnr)
        local function map(mode, lhs, rhs, opts)
            opts = vim.tbl_extend("force", {noremap = true, silent = true}, opts or {})
            vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
        end

        -- Navigation
        map("n", "]c", "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'", {expr = true})
        map("n", "[c", "&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'", {expr = true})

        -- Actions
        map("n", "<leader>rh", ":Gitsigns reset_hunk<CR>")
        map("v", "<leader>rh", ":Gitsigns reset_hunk<CR>")
        map("n", "<leader>ph", "<cmd>Gitsigns preview_hunk<CR>")
        map("n", "<leader>bl", '<cmd>lua require"gitsigns".blame_line{full=true}<CR>')
        map("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<CR>")
        map("n", "<leader>dt", "<cmd>Gitsigns diffthis<CR>")
        -- map("n", "<leader>ggd", '<cmd>lua require"gitsigns".diffthis("~")<CR>')
        -- map("n", "<leader>td", "<cmd>Gitsigns toggle_deleted<CR>")

        -- Text object
        map("o", "ih", ":<C-U>Gitsigns select_hunk<CR>")
        map("x", "ih", ":<C-U>Gitsigns select_hunk<CR>")
    end
}

vim.highlight.create("GitSignsCurrentLineBlame", {guifg = "#8b9898"}, false)
vim.highlight.create("GitSignsChange", {guifg = "orange", guibg = "NONE"}, false)

function toggleSignColumn()
    vim.o.signcolumn = vim.o.signcolumn == "yes" and "no" or "yes"
end

utils.map(
    "n",
    "<S-c>",
    ":lua toggleSignColumn()<cr>",
    {
        noremap = false,
        silent = true
    }
)
