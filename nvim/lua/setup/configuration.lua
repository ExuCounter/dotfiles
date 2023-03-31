local opt = vim.opt

opt.splitright = true
opt.splitbelow = true

opt.re = 0

opt.signcolumn = "yes"
opt.cmdheight = 1
opt.updatetime = 200
opt.shortmess = "c"
opt.pumheight = 8
opt.textwidth = 100

opt.encoding = "utf-8"
opt.mouse = "a"
opt.cursorline = true -- highlight current line
opt.ruler = true -- show the cursor position

opt.shortmess = "atI" -- don't show the intro message when starting Vim
opt.indentexpr = ""
opt.showmatch = true -- highlight matching [{()}] "
opt.showmode = true --show the current mode
opt.hidden = true -- allow unsaved background buffers and remember marks/undo for them
opt.scrolloff = 11 -- minimal lines around the cursor

opt.number = true
opt.lazyredraw = true -- improve scrolling performance when navigating through large results
opt.smartcase = true -- improve scrolling performance when navigating through large results
opt.ignorecase = true -- ignore case only when the pattern contains no capital letters

opt.timeout = true
opt.timeoutlen = 500
opt.ttimeoutlen = 100

opt.complete = ".,w,b,u,t,i,kspell"
opt.completeopt = "menu,menuone,noselect"
opt.whichwrap = "<,h"

opt.background = "light" -- colorscheme

opt.foldenable = true -- dont fold by default
opt.foldmethod = "indent" -- fold based on spaces
opt.foldlevelstart = 10 -- open most folds by default
opt.foldnestmax = 10 -- 10 nested fold max

opt.whichwrap:append "<>[]hl"

opt.tabstop = 2 -- read as
opt.softtabstop = 2 -- insert as
opt.expandtab = true -- tabs are spaces
opt.smartindent = true
opt.shiftwidth = 2

opt.numberwidth = 4
opt.scroll = 10

opt.fillchars = {
    vert = "│",
    fold = "⠀",
    eob = " ", -- suppress ~ at EndOfBuffer
    msgsep = " ",
    foldopen = "▾",
    foldsep = " ",
    foldclose = "▸"
}

opt.termguicolors = true

local THEME_REPLACEMENTS = {
    -- old / new
    colors = {
        ["purples\\.0"] = "alpha.300",
        ["purples\\.1"] = "alpha.600",
        ["purples\\.2"] = "alpha.700",
        ["purples\\.3"] = "alpha.800",
        ["purples\\.7"] = "alpha.500",
        ["grays\\.1"] = "beta.100",
        ["grays\\.2"] = "beta.200",
        ["grays\\.3"] = "beta.300",
        ["grays\\.4"] = "beta.300",
        ["grays\\.5"] = "beta.300",
        ["grays\\.7"] = "beta.400",
        ["grays\\.8"] = "beta.500",
        ["grays\\.9"] = "beta.600",
        ["grays\\.10"] = "beta.700",
        ["grays\\.11"] = "beta.800",
        ["reds\\.0"] = "delta.400",
        ["reds\\.1"] = "delta.500",
        ["gold"] = "epsilon.400",
        ["orange"] = "epsilon.500",
        ["transparent"] = "newTransparent.0",
        ["whites\\.0"] = "newTransparent.100",
        ["whites\\.1"] = "newTransparent.400",
        ["whites\\.2"] = "newTransparent.600",
        ["whites\\.3"] = "white"
    },
    -- new / old
    spaces = {
        ["1"] = 0,
        ["2"] = 1,
        ["3"] = 2,
        ["4"] = 2,
        ["5"] = 2,
        ["6"] = 2,
        ["7"] = 3,
        ["8"] = 3,
        ["9"] = 4,
        ["10"] = 5,
        ["11"] = 5,
        ["12"] = 6,
        ["13"] = 6,
        ["14"] = 7,
        ["15"] = 7,
        ["16"] = 8,
        ["17"] = 9
    },
    -- old / new
    fontSizes = {
        ["0"] = 0,
        ["1"] = 4,
        ["2"] = 5,
        ["3"] = 6,
        ["4"] = 7,
        ["5"] = 7,
        ["6"] = 8,
        ["7"] = 9
    }
}

local THEME_REPLACEMENT_IDENTIFIERS = {
    spaces = {
        "my",
        "mb",
        "mr",
        "ml",
        "mx",
        "mt",
        "m",
        "py",
        "pb",
        "pl",
        "pr",
        "px",
        "pt",
        "p"
    },
    fontSize = "fontSize"
}

local function getReplacementString(old, new, flags)
    return "%s/" .. old .. "/" .. new .. "/" .. flags .. " | "
end

local function all_trim(s)
    return string.gsub(s, "%s+", "")
end

local function getReplacementColorsString(colors)
    local str = ""

    for old, new in pairs(colors) do
        str = str .. getReplacementString(old, new, "gec")
    end

    return str
end

local function getReplacementComponents()
    local bufferLines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local toBeReplacedItems = {}

    for i = 1, table.getn(bufferLines) do
        print(bufferLines[i])
        if (string.match(bufferLines[i], "@prosapient/prosapient.ui")) then
            local capturedImportGroup = all_trim(string.match(bufferLines[i], "{(.*)}"))

            for k in string.gmatch(capturedImportGroup, "([^,]+),?") do
                table.insert(toBeReplacedItems, k)
            end
        end
    end

    return toBeReplacedItems

    -- ":ReplaceOldKit<CR>",
end

local function getReplacementSpacesString(spaces, spacingIdentifiers)
    local str = ""

    local componentNames = getReplacementComponents()

    for new, old in pairs(spaces) do
        for _, identifier in pairs(spacingIdentifiers) do
            for componentName in pairs(componentNames) do
                str =
                    str ..
                    getReplacementString(
                        -- space sign to avoid collision with wrong subtitute
                        "<" .. componentName .. ".*" .. identifier .. "={" .. old .. "}",
                        -- plugs sign to avoid duplicated replacements
                        "<" .. componentName .. ".*" .. identifier .. "+={" .. new .. "}",
                        "gec"
                    )
            end
        end
    end

    for _ in pairs(spaces) do
        for _, identifier in pairs(spacingIdentifiers) do
            for componentName in pairs(componentNames) do
                str =
                    str ..
                    getReplacementString(
                        -- space sign to avoid collision with wrong subtitute
                        "<" .. componentName .. ".*" .. identifier .. "+",
                        -- plugs sign to avoid duplicated replacements
                        "<" .. componentName .. ".*" .. identifier,
                        "gec"
                    )
            end
        end
    end

    return str
end

local function getReplacementFontSizesString(fontSizes, fontSizeIdentifier, componentNames)
    local str = ""

    for old, new in pairs(fontSizes) do
        str =
            str ..
            getReplacementString(
                fontSizeIdentifier .. "={" .. old .. "}",
                -- plugs sign to avoid duplicated replacements
                fontSizeIdentifier .. "+" .. "={" .. new .. "}",
                "ge"
            )
    end

    for _ in pairs(fontSizes) do
        str = str .. "%s/fontSize+/fontSize/ge" .. " | "
        getReplacementString(
            fontSizeIdentifier .. "+",
            -- remove plus sign after all replacements
            fontSizeIdentifier,
            "ge"
        )
    end

    return str
end

vim.api.nvim_create_user_command(
    "ReplaceOldColors",
    getReplacementColorsString(THEME_REPLACEMENTS.colors),
    {bar = true}
)
vim.api.nvim_create_user_command(
    "ReplaceOldFontSizes",
    getReplacementFontSizesString(THEME_REPLACEMENTS.fontSizes, THEME_REPLACEMENT_IDENTIFIERS.fontSize),
    {bar = true}
)
vim.api.nvim_create_user_command(
    "ReplaceOldSpaces",
    getReplacementSpacesString(THEME_REPLACEMENTS.spaces, THEME_REPLACEMENT_IDENTIFIERS.spaces),
    {bar = true}
)
vim.api.nvim_create_user_command(
    "ReplaceOldKit",
    "ReplaceOldColors|ReplaceOldSpaces|ReplaceOldFontSizes|echo 'ui-kit replaced'",
    {}
)

-- vim.keymap.set(
--     "n",
--     ";",
--     function()
--         local bufferLines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
--         local toBeReplacedItems = {}
--         local lineNumber = nil

--         local lineNumber2 = nil

--         for i = 1, table.getn(bufferLines) do
--             print(bufferLines[i])
--             if (string.match(bufferLines[i], "form.bindings.new")) then
--                 local capturedImportGroup = all_trim(string.match(bufferLines[i], "{(.*)}"))
--                 lineNumber = i

--                 for k in string.gmatch(capturedImportGroup, "([^,]+),?") do
--                     table.insert(toBeReplacedItems, k)
--                 end
--             end

--             if (string.match(bufferLines[i], "form.selects.new")) then
--                 lineNumber2 = i
--             end
--         end

--         print(lineNumber2)

--         if lineNumber2 then
--             vim.api.nvim_buf_set_lines(0, lineNumber2 - 1, lineNumber2, true, {})
--         end

--         if table.getn(toBeReplacedItems) > 0 then
--             vim.api.nvim_buf_set_lines(
--                 0,
--                 lineNumber - 1,
--                 lineNumber,
--                 true,
--                 {'import { FormBindings } from "shared/form-bindings-new"'}
--             )

--             local replacing = {
--                 "Input",
--                 "Checkbox",
--                 "CheckboxFeature",
--                 "Datepicker",
--                 "Daterange",
--                 "PhoneInput",
--                 "InputFile",
--                 "Radio",
--                 "YesNoRadio",
--                 "RichTextEditor",
--                 "Textarea",
--                 "Timepicker",
--                 "Toggle",
--                 "Select",
--                 "AsyncSelect",
--                 "CreatableSelect",
--                 "AsyncCreatableSelect",
--                 "TimezoneSelect",
--                 "AngleRoleSelect",
--                 "AngleSelect",
--                 "ByoeExpertSourceSelect",
--                 "ChargeCodesSelect",
--                 "ClientSearchSelect",
--                 "CompaniesSelect",
--                 "CurrenciesSelect",
--                 "DurationSelect",
--                 "LengthOfInterviewSelect",
--                 "LocationsSelect",
--                 "MonthSelect",
--                 "ProjectIndustrySelect",
--                 "ProjectSearchSelect",
--                 "YearSelect",
--                 "TranscriptCompaniesSelect",
--                 "RolesAndJobTitlesSelect",
--                 "RepresentativeRoleSelect",
--                 "RepresentativeSelect",
--                 "ProjectTypeSelect",
--                 "TimeSelect"
--             }

--             local str = ""

--             for _, value in pairs(replacing) do
--                 str =
--                     str ..
--                     getReplacementString(
--                         "<" .. value,
--                         -- plugs sign to avoid duplicated replacements
--                         "<FormBindings." .. value,
--                         "ge"
--                     )
--             end

--             vim.cmd(str)
--         end

--         -- print(vim.inspect(toBeReplacedItems))

--         -- ":ReplaceOldKit<CR>",
--     end,
--     {
--         noremap = true
--     }
-- )

vim.keymap.set(
    "n",
    ";",
    function()
        local bufferLines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
        local replacingLineNumber = nil
        local deletingLineNumber = nil
        local capturedImports = {}

        for i = 1, table.getn(bufferLines) do
            if (string.match(bufferLines[i], "prosapient.prosapient.styleguide")) then
                if (string.match(bufferLines[i], "SelectOption")) then
                    replacingLineNumber = i
                else
                    deletingLineNumber = i

                    local capturedImportGroup = all_trim(string.match(bufferLines[i], "{(.*)}"))
                    for k in string.gmatch(capturedImportGroup, "([^,]+),?") do
                        table.insert(capturedImports, k)
                    end
                end
            end
        end

        if (replacingLineNumber and deletingLineNumber) then
            vim.api.nvim_buf_set_lines(
                0,
                deletingLineNumber - 1,
                deletingLineNumber,
                true,
                {
                    "import { " ..
                        table.concat(capturedImports, ", ") ..
                            ", SelectOption" .. " }" .. ' from "@prosapient/prosapient-styleguide"'
                }
            )
            vim.api.nvim_buf_set_lines(0, replacingLineNumber - 1, replacingLineNumber, true, {})
        end

        vim.cmd("Gwrite")
    end,
    {
        noremap = true
    }
)

vim.cmd(
    [[
filetype plugin on
syntax on

colorscheme solarized8_flat

" hi EndOfBuffer guifg=#fdf6e3
hi MatchParen guifg=NONE gui=underline cterm=underline ctermbg=66 guifg=white guibg=#b3b3b3
hi VertSplit guibg=NONE guifg=#b3b3b3
autocmd FileType * set formatoptions+=t

hi ConflictMarkerBegin guibg=#e6cd85 guifg=#FFFFFF
hi ConflictMarkerOurs guibg=#FAEFD1
hi ConflictMarkerTheirs guibg=#DDEFFA
hi ConflictMarkerEnd guibg=#F5DDDC guifg=NONE 
hi ConflictMarkerSeparator guibg=NONE guifg=NONE 
hi ConflictMarkerCommonAncestorsHunk guibg=NONE
hi ConflictMarkerCommonAncestors guibg=NONE

hi BufferLineFill ctermbg=254 guibg=#eee8d5
hi BufferLineBufferSelected gui=bold cterm=bold
highlight IndentBlanklineChar guifg=#8b9898 gui=nocombine guibg=NONE
hi typescriptParens guifg=#6d8086
hi DevIconJs guifg=orange 
hi DevIconEnv guifg=orange 
hi IndentBlanklineChar guifg=#b3b3b3

" hi MsgArea guifg=#657b83 guibg=#eee8d5
" hi NvimTreeNormal guifg=#657b83 guibg=#eee8d

hi DiagnosticUnderlineWarn gui=undercurl cterm=undercurl
hi DiagnosticUnderlineHint gui=undercurl cterm=undercurl
hi DiagnosticUnderlineError gui=undercurl cterm=undercurl
hi DiagnosticUnderlineInfo gui=undercurl cterm=undercurl
hi DiagnosticUnderlineHint gui=undercurl cterm=undercurl

hi Error cterm=NONE gui=NONE guifg=NONE ctermbg=NONE

hi CmpItemAbbrMatch guifg=#cb4b16
hi GitSignsCurrentLineBlame gui=italic

function! s:GotoFirstFloat() abort
  for w in range(1, winnr('$'))
    let c = nvim_win_get_config(win_getid(w))
    if c.focusable && !empty(c.relative)
      execute w . 'wincmd w'
    endif
  endfor
endfunction
noremap <c-w><space> :<c-u>call <sid>GotoFirstFloat()<cr>
]]
)

vim.g.mapleader = " "

vim.g["far#enable_undo"] = 1

vim.g.solarized_visibility = "high"
vim.g.solarized_extra_hi_groups = 1

vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_show_database_icon = 1

vim.g.db_ui_force_echo_notifications = 0

vim.g.matchup_matchparen_offscreen = {}

vim.g.db_ui_win_position = "right"
vim.g.db_ui_save_location = "~/.config/db_ui/queries"

vim.g.dbs = {
    dev = {name = "prosapient_dev", url = "postgres://postgres:postgres@localhost:5432/prosapient_dev"},
    byoe = {name = "prosapient_dev_byoe", url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_byoe"},
    learning_sql = {name = "learning_sql", url = "postgres://postgres:postgres@localhost:5432/learning_sql"},
    aggregator = {
        name = "prosapient_dev_aggregator",
        url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_aggregator"
    },
    lek = {name = "prosapient_dev_lek", url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_lek"},
    mckinsey = {
        name = "prosapient_dev_mckinsey",
        url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_mckinsey"
    },
    outreach = {
        name = "prosapient_dev_outreach",
        url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_outreach"
    }
}

for _, keymap in pairs(
    {
        "zo",
        "zO",
        "zc",
        "zC",
        "za",
        "zA",
        "zv",
        "zx",
        "zX",
        "zm",
        "zM",
        "zr",
        "zR"
    }
) do
    vim.api.nvim_set_keymap("n", keymap, keymap .. "<CMD>IndentBlanklineRefresh<CR>", {noremap = true, silent = true})
end

vim.g.delimitMate_matchpairs = "(:),[:],{:}"
vim.g.delimitMate_expand_space = 1
vim.g.delimitMate_balance_matchpairs = 1
vim.g.delimitMate_expand_cr = 1

vim.g["far#source"] = "agnvim"
vim.g["far#auto_preview"] = 0
