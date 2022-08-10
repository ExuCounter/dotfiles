local vimp = require("vimp")

-- setup with all defaults
-- each of these are documented in `:help nvim-tree.OPTION_NAME`
require("nvim-tree").setup(
    {
        -- BEGIN_DEFAULT_OPTS
        auto_reload_on_write = true,
        disable_netrw = true,
        hijack_cursor = false,
        hijack_netrw = false,
        hijack_unnamed_buffer_when_opening = false,
        ignore_buffer_on_setup = false,
        open_on_setup = false,
        open_on_setup_file = false,
        open_on_tab = false,
        sort_by = "name",
        update_cwd = false,
        view = {
            adaptive_size = true,
            width = 42,
            height = 30,
            side = "left",
            hide_root_folder = true,
            preserve_window_proportions = false,
            number = true,
            relativenumber = false,
            signcolumn = "no",
            mappings = {
                custom_only = true,
                list = {
                    {key = "<C-t>", action = "close"},
                    {key = "t", action = "new %"},
                    {key = "R", action = "refresh"},
                    {key = "d", action = "remove"},
                    {key = "D", action = "trash"},
                    {key = "x", action = "cut"},
                    {key = "c", action = "copy"},
                    {key = "p", action = "paste"},
                    {key = "v", action = "vsplit"},
                    {key = "<Tab>", action = "preview"},
                    {key = "a", action = "create"},
                    {key = "i", action = "toggle_file_info"},
                    {key = "y", action = "copy_name"},
                    {key = "Y", action = "copy_path"},
                    {key = "r", action = "rename"},
                    {key = "-", action = "dir_up"},
                    {key = "=", action = "cd"},
                    {key = {"<CR>", "o", "<2-LeftMouse>"}, action = "edit"}
                }
            }
        },
        renderer = {
            indent_markers = {
                enable = true,
                icons = {
                    corner = "└",
                    edge = "│",
                    none = ""
                }
            },
            icons = {
                webdev_colors = true
            }
        },
        hijack_directories = {
            enable = true,
            auto_open = true
        },
        update_focused_file = {
            enable = true,
            ignore_list = {}
        },
        system_open = {
            cmd = nil,
            args = {}
        },
        diagnostics = {
            enable = false,
            show_on_dirs = false,
            icons = {
                hint = "",
                info = "",
                warning = "",
                error = ""
            }
        },
        filters = {
            dotfiles = false,
            custom = {},
            exclude = {}
        },
        git = {
            enable = true,
            ignore = true,
            timeout = 400
        },
        actions = {
            use_system_clipboard = true,
            change_dir = {
                enable = true,
                global = false,
                restrict_above_cwd = false
            },
            open_file = {
                quit_on_open = true,
                resize_window = true,
                window_picker = {
                    enable = true,
                    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
                    exclude = {
                        filetype = {"notify", "packer", "qf", "diff", "fugitive", "fugitiveblame"},
                        buftype = {"nofile", "terminal", "help"}
                    }
                }
            }
        }
    }
) -- END_DEFAULT_OPTSg

vimp.nmap("<C-t>", ":NvimTreeToggle<CR>")
vimp.nmap({"chord"}, "<leader>r", ":NvimTreeRefresh<CR>")
vimp.nnoremap({"chord"}, "<leader>t", ":NvimTreeFindFile<CR>")
