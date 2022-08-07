require("marks").setup(
    {
        -- whether to map keybinds or not. default true
        default_mappings = true,
        signs = "yes",
        -- which builtin marks to show. default {}
        builtin_marks = {"<", ">", "^"},
        -- whether movements cycle back to the beginning/end of buffer. default true
        cyclic = true,
        -- whether the shada file is updated after modifying uppercase marks. default false
        force_write_shada = false,
        refresh_interval = 250,
        sign_priority = {lower = 10, upper = 15, builtin = 8, bookmark = 20},
        -- disables mark tracking for specific filetypes. default {}
        excluded_filetypes = {
            NvimTree_1 = false
        },
        mappings = {}
    }
)
