local present, marks = pcall(require, "marks")

if not present then
    return
end

marks.setup(
    {
        default_mappings = true,
        signs = "yes",
        builtin_marks = {"<", ">", "^"},
        cyclic = true,
        force_write_shada = false,
        refresh_interval = 250,
        sign_priority = {lower = 10, upper = 15, builtin = 8, bookmark = 20},
        excluded_filetypes = {
            NvimTree_1 = false
        },
        mappings = {}
    }
)
