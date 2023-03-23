local M = {}

local getBranch = vim.fn["gitbranch#name"]

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

vim.api.nvim_create_user_command("Rg", ":lua require('fzf-lua').live_grep({search=<f-args>})", {nargs = 1})

local function removeExtension(s)
    return s:match("(.+)%..+")
end

local function copy_path()
    local path = vim.fn.expand("%:p")
    local i, j = string.find(path, "frontend/src/")
    if i and j then
        local relativePath = string.sub(path, j + 1, -1)
        path = removeExtension(relativePath)
    end
    vim.fn.setreg("+", path)
    return path
end

vim.api.nvim_create_user_command(
    "CopyPath",
    function()
        local path = copy_path()
        vim.notify('Copied "' .. path .. '" to the clipboard!')
    end,
    {}
)

local function makeImportPath()
    local path = copy_path()
    local variable = vim.fn.expand("<cWORD>"):gsub(":", "")
    path = "import " .. "{ " .. variable .. " }" .. " from " .. "'" .. path .. "'"
    vim.fn.setreg("+", path)
    return path
end

vim.api.nvim_create_user_command(
    "MakeImport",
    function()
        local path = makeImportPath()
        vim.notify('Copied "' .. path .. '" to the clipboard!')
    end,
    {}
)

local defaults = {
    insert_mode = {
        -- Return to normal mode
        ["jj"] = "<ESC>",
        -- Save on CTRL + S,
        ["<C-S>"] = "<Esc>:w!<CR>",
        -- Disable Arrow keys in Insert mode
        ["<up>"] = "<nop>",
        ["<down>"] = "<nop>",
        ["<left>"] = "<nop>",
        ["<right>"] = "<nop>",
        -- Move lines
        ["∆"] = "<Esc>:m .+1<CR>==gi",
        ["˚"] = "<Esc>:m .-2<CR>==gi"
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
        ["<leader>db"] = ":DBUIToggle<cr>",
        -- Close buffers
        ["<leader>cb"] = "<cmd>lua require('close_buffers').delete({ type = 'hidden', force = true })<cr>",
        -- Reload lua config
        ["<leader>0"] = function()
            -- Unload the lua namespace so that the next time require('config.X') is called
            -- it will reload the file
            require("setup/util").unload_lua_namespace("setup")
            -- Make sure all open buffers are saved
            vim.cmd("silent wa")
            -- Execute our vimrc lua file again to add back our maps
            dofile(os.getenv("HOME") .. "/nvim/lua/init.lua")

            print("Reloaded vimrc!")
        end,
        -- Git windows shortcuts
        ["<leader>gcm"] = ":Git commit -v -q <CR>",
        ["<leader>gd"] = ":Git diff<CR>",
        ["<leader>gcl"] = ":Gclog -50<CR>",
        ["<leader>gl"] = ":Git log -50<CR>",
        ["<C-g>"] = ":GFiles?<cr>",
        ["<leader>g"] = ":Git<cr>",
        ["<leader>G"] = ":Git<cr>",
        -- Git push/pull/fetch shortcuts
        ["<Leader>gbp"] = ":Git -c push.default=current push<CR>",
        ["<Leader>gpf"] = ":Git -c push.default=current push --force<CR>",
        ["<Leader>gpl"] = ":Git pull origin " .. getBranch() .. "<CR>",
        ["<Leader>gfa"] = ":Git fetch --all<CR>",
        -- Git rebase/blame/checkout/reset shortcuts
        ["<Leader>grc"] = ":Git rebase --continue<CR>",
        ["<Leader>gra"] = ":Git rebase --abort",
        ["<Leader>grsh"] = ":Git reset --hard",
        ["<Leader>gri"] = ":Git rebase --interactive HEAD~",
        ["<Leader>gcb"] = ":Git checkout -b",
        ["<Leader>gbl"] = ":Git blame -et<CR>",
        -- Moves
        ["C-u"] = ':lua require("neoscroll").scroll(-80, true, 100)<CR>',
        ["C-d"] = ':lua require("neoscroll").scroll(80, true, 100)<CR>',
        ["zt"] = ':lua require("neoscroll").zb(250)<CR>',
        ["zb"] = ':lua require("neoscroll").zt(250)<CR>',
        -- Disable Arrow keys in Normal mode
        ["<up>"] = "<nop>",
        ["<down>"] = "<nop>",
        ["<left>"] = "<nop>",
        ["<right>"] = "<nop>",
        -- Move lines by alt + arrows
        ["∆"] = ":m .+1<CR>==",
        ["˚"] = ":m .-2<CR>==",
        -- Accelerated_jk
        ["j"] = "<Plug>(accelerated_jk_gj)",
        ["k"] = "<Plug>(accelerated_jk_gk)",
        -- Diagnostics
        ["cn"] = "<cmd>lua vim.diagnostic.goto_next()<CR>",
        ["cN"] = "<cmd>lua vim.diagnostic.goto_prev()<CR>",
        -- Navigation
        ["C-k"] = ":wincmd k<CR>",
        ["C-j"] = ":wincmd j<CR>",
        ["C-h"] = ":wincmd h<CR>",
        ["C-l"] = ":wincmd l<CR>"
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
        ["s"] = "<cmd>lua require'hop'.hint_char1()<cr>",
        -- Move lines
        ["∆"] = ":m '>+1<CR>gv-gv",
        ["˚"] = ":m '<-2<CR>gv-gv",
        -- Comments
        ["gc"] = "<Plug>Commentary"
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
