local vimp = require("vimp")

local M = {}

local generic_opts_any = {noremap = true, silent = true}

local generic_opts = {
    insert_mode = generic_opts_any,
    normal_mode = generic_opts_any,
    visual_mode = generic_opts_any,
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
    command_mode = "c"
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
        ["p"] = '"_dP',
        -- Buffers
        ["<leader>v"] = ":vnew %<cr>",
        ["<leader>ev"] = ":vnew <cr>",
        ["<leader>s"] = ":new %<cr>",
        ["<leader>l"] = ":bn <cr>",
        ["<leader>h"] = ":bp <cr>"
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
        ["p"] = '"_dP'
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
