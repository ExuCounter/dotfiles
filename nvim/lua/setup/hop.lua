local utils = require("setup/utils")
local hop = require("hop")

hop.setup(
    {
        create_hl_autocmd = false,
        extend_visual = true
    }
)

-- Fast search by character
utils.map("n", "S", "<cmd>lua require'hop'.hint_char2()<cr>")
utils.map("n", "s", "<cmd>lua require'hop'.hint_char1()<cr>")
utils.map("v", "s", "<cmd>lua require'hop'.hint_char1()<cr>")

utils.map(
    "n",
    "f",
    "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>"
)

utils.map(
    "n",
    "F",
    "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>"
)

utils.map(
    "o",
    "f",
    "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true, inclusive_jump = true })<cr>"
)

utils.map(
    "o",
    "F",
    "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true, inclusive_jump = true })<cr>"
)

utils.map(
    "n",
    "t",
    "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>"
)

utils.map(
    "n",
    "T",
    "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>"
)
