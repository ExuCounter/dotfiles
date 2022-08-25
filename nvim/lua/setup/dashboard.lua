vim.g.indentLine_fileTypeExclude = {"alpha"}

local function button(sc, txt, keybind)
    local sc_ = sc:gsub("%s", ""):gsub("SPC", "<leader>")

    local opts = {
        position = "center",
        text = txt,
        shortcut = sc,
        cursor = 5,
        width = 36,
        align_shortcut = "right",
        hl = "AlphaButtons"
    }

    if keybind then
        opts.keymap = {"n", sc_, keybind, {noremap = true, silent = true}}
    end

    return {
        type = "button",
        val = txt,
        on_press = function()
            local key = vim.api.nvim_replace_termcodes(sc_, true, false, true)
            vim.api.nvim_feedkeys(key, "normal", false)
        end,
        opts = opts
    }
end

-- require "alpha".setup(
--     {
--         layout = {
--             header = {
--                 type = "text",
--                 val = {
--                     "",
--                     "",
--                     "",
--                     "",
--                     "",
--                     "",
--                     "",
--                     "..... (¯`v´¯)♥",
--                     ".......•.¸.•´",
--                     "....¸.•´",
--                     "...(",
--                     "☻ /",
--                     "/▌♥♥",
--                     "/ \\ ♥♥",
--                     "",
--                     ""
--                 },
--                 opts = {
--                     position = "center"
--                 }
--             },
--             buttons = {
--                 type = "group",
--                 val = {
--                     {type = "button", val = ""},
--                     {type = "button", val = ""},
--                     {type = "button", val = ""}
--                 },
--                 opts = {
--                     spacing = 1
--                 }
--             }
--         },
--         opts = {}
--     }
-- )

vim.cmd(
    [[
    autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
    autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
 let g:dashboard_custom_header =[
 \'',
 \'',
 \'',
 \'',
 \'',
 \'',
 \'',
 \'..... (¯`v´¯)♥',
 \'.......•.¸.•´',
 \'....¸.•´',
 \'...(',
 \'☻ /',
 \'/▌♥♥',
 \'/ \ ♥♥',
 \]

 let g:dashboard_custom_footer = [
 			\"Don't worry if something doesn't work. If everything worked, you would be fired. ",
 			\"- Mosher’s Law of Software Engineering"]

 let g:dashboard_custom_shortcut={
 \ 'last_session'       : '<leader>ls',
 \ 'find_history'       : '<leader>h',
 \ 'find_file'          : '<leader>f',
 \ 'new_file'           : 'SPC c n',
 \ 'change_colorscheme' : 'SPC t c',
 \ 'find_word'          : 'SPC f a',
 \ 'book_marks'         : 'SPC f b',
 \ }
 let g:dashboard_default_executive ='fzf'

 let g:dashboard_custom_section={
   \ 'b': {
 	\ 'description': ['  Find Word                 <C-p>     '],
 	\ 'command': "Rg"},
   \ 'c': {
 	\ 'description': ['  Exit                      leader q  '],
 	\ 'command': "exit"},
   \ 'a': {
 	\ 'description': ['  Find file                 <C-f>     '],
 	\ 'command': "Files"}
 	\ }

  ]]
)
