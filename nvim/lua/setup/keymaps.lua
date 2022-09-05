local vimp = require("vimp")

local M = {}

local generic_opts_any = {noremap = true, silent = true}

local generic_opts = {
    insert_mode = generic_opts_any,
    normal_mode = generic_opts_any,
    visual_mode = generic_opts_any,
    operator_mode = generic_opts_any,
    visual_block_mode = generic_opts_any,
    command_mode = generic_opts_any,
    term_mode = {silent = true}
}

local mode_adapters = {
    insert_mode = "i",
    normal_mode = "n",
    term_mode = "t",
    visual_mode = "v",
    visual_block_mode = "x",
    command_mode = "c",
    operator_mode = "o"
}

local defaults = {
    insert_mode = {
        -- Return to normal mode
        ["jj"] = "<ESC>",
        -- Save on CTRL + S,
        ["<C-S>"] = "<Esc>:w!<CR>"
    },
    normal_mode = {
        -- Copy path
        ["cp"] = ":CopyPath<CR>",
        -- Untitled file
        ["<leader>u"] = {":e untitled.txt", {silent = false}},
        -- Save on CTRL + S
        ["<C-S>"] = ":w!<CR>",
        -- Fast exit from buffer
        ["<Leader>q"] = ":bd!<cr>",
        -- Clear highlighting on escape in normal mode
        ["<Esc>"] = ":noh<cr><esc>",
        -- Comments
        ["gc"] = "<Plug>Commentary",
        ["gcc"] = "<Plug>CommentaryLine",
        -- Marks
        ["<leader>dm"] = ":delmarks A-Za-z0-9<cr>",
        ["<leader>ms"] = ":DoShowMarks!<cr>",
        -- Copy to buffer on delete / paste / yank
        ["<leader>y"] = '"*y',
        ["<leader>Y"] = '"*y$',
        ["<leader>x"] = '"*x',
        ["<leader>dd"] = '"*dd',
        ["<leader>D"] = '"*D',
        ["<leader>p"] = '"_dP',
        -- Buffers
        ["<leader>v"] = ":vnew %<cr>",
        ["<leader>ev"] = ":vnew <cr>",
        ["<leader>s"] = ":new %<cr>",
        ["<leader>l"] = ":bn <cr>",
        ["<leader>h"] = ":bp <cr>",
        -- FZF
        ["<C-f>"] = ":FzfLua files<CR>",
        -- ["<C-g>"] = ":FzfLua git_files<CR>",
        ["<C-q>"] = ":FzfLua command_history<CR>",
        ["<C-p>"] = ":FzfLua grep_project<CR>",
        ["<C-b>"] = ":FzfLua buffers<CR>",
        ["<leader>gco"] = ":FzfLua git_branches<CR>",
        -- NvimTree
        ["<C-t>"] = ":NvimTreeToggle<CR>",
        ["<leader>r"] = ":NvimTreeRefresh<CR>",
        ["<leader>t"] = ":NvimTreeFindFile<CR>",
        -- BufferLine`
        ["<leader>1"] = "<cmd> lua require('bufferline').go_to_buffer(1, true)<cr>",
        ["<leader>2"] = "<cmd> lua require('bufferline').go_to_buffer(2, true)<cr>",
        ["<leader>3"] = "<cmd> lua require('bufferline').go_to_buffer(3, true)<cr>",
        ["<leader>4"] = "<cmd> lua require('bufferline').go_to_buffer(4, true)<cr>",
        ["<leader>5"] = "<cmd> lua require('bufferline').go_to_buffer(5, true)<cr>",
        ["<leader>6"] = "<cmd> lua require('bufferline').go_to_buffer(6, true)<cr>",
        ["<leader>7"] = "<cmd> lua require('bufferline').go_to_buffer(7, true)<cr>",
        ["<leader>8"] = "<cmd> lua require('bufferline').go_to_buffer(8, true)<cr>",
        ["<leader>9"] = "<cmd> lua require('bufferline').go_to_buffer(9, true)<cr>",
        -- Hop
        ["f"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>",
        ["F"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>",
        ["t"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>",
        ["T"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>",
        ["S"] = "<cmd>lua require'hop'.hint_char2()<cr>",
        ["s"] = "<cmd>lua require'hop'.hint_char1()<cr>",
        -- DB
        ["<leader>dt"] = ":DBUIToggle<cr>"
    },
    visual_mode = {
        -- Save on CTRL + S,
        ["<C-S>"] = "<Esc>:w!<CR>",
        -- Copy to buffer on delete / paste / yank
        ["<leader>y"] = '"*y',
        ["<leader>Y"] = '"*y$',
        ["<leader>x"] = '"*x',
        ["<leader>dd"] = '"*dd',
        ["<leader>D"] = '"*D',
        ["p"] = '"_dP',
        -- Hop
        ["f"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>",
        ["F"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>",
        ["t"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>",
        ["T"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>",
        ["s"] = "<cmd>lua require'hop'.hint_char1()<cr>"
    },
    operator_mode = {
        -- Hop
        ["f"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true, inclusive_jump = true })<cr>",
        ["F"] = "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true, inclusive_jump = true })<cr>"
    }
}

function M.set_keymaps(mode, key, val)
    local opt = generic_opts[mode] or generic_opts_any
    if type(val) == "table" then
        opt = val[2]
        val = val[1]
    end
    if val then
        vim.keymap.set(mode, key, val, opt)
    else
        pcall(vim.api.nvim_del_keymap, mode, key)
    end
end

-- Load key mappings for a given mode
-- @param mode The keymap mode, can be one of the keys of mode_adapters
-- @param keymaps The list of key mappings
function M.load_mode(mode, keymaps)
    mode = mode_adapters[mode] or mode
    for k, v in pairs(keymaps) do
        M.set_keymaps(mode, k, v)
    end
end

-- Load key mappings for all provided modes
-- @param keymaps A list of key mappings for each mode
function M.load(keymaps)
    keymaps = keymaps or {}
    for mode, mapping in pairs(keymaps) do
        M.load_mode(mode, mapping)
    end
end

-- Load the default keymappings
function M.load_defaults()
    M.load(M.get_defaults())
end

-- Get the default keymappings
function M.get_defaults()
    return defaults
end

M.load_defaults()

return M
