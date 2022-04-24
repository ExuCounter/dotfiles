-- setup with all defaults
-- each of these are documented in `:help nvim-tree.OPTION_NAME`
require'nvim-tree'.setup { -- BEGIN_DEFAULT_OPTS
  auto_reload_on_write = true,
	auto_resize = true,
  disable_netrw = true,
  hide_root_folder = true,
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
    width = 40,
    height = 30,
    side = "left",
    preserve_window_proportions = false,
    number = true,
    relativenumber = false,
    signcolumn = "no",
    mappings = {
      custom_only = true,
      list = {
        { key = "<C-t>", action = "close" },
        { key = "t", action = "tabnew" },
        { key = "R", action = "refresh" },
        { key = "d", action = "remove" },
        { key = "D", action = "trash" },
        { key = "x", action = "cut" },
        { key = "c", action = "copy" },
        { key = "p", action = "paste" },
        { key = "v", action = "vsplit" },
        { key = "<Tab>", action = "preview" },
        { key = "a", action = "create" },
        { key = "i", action = "toggle_file_info" },
        { key = "y", action = "copy_name" },
        { key = "Y", action = "copy_path" },
				{ key = "r", action = "rename" },
				{ key = "-", action = "dir_up" },
				{ key = "=", action = "cd" },
				{ key = {"<CR>", "o", "<2-LeftMouse>"}, action = "edit" },
      },
    },
  },
  renderer = {
    indent_markers = {
      enable = false,
      icons = {
        corner = "└ ",
        edge = "│ ",
        none = "  ",
      },
    },
    icons = {
      webdev_colors = true,
    },
  },
  hijack_directories = {
    enable = true,
    auto_open = true,
  },
  update_focused_file = {
    enable = false,
    update_cwd = false,
    ignore_list = {},
  },
  ignore_ft_on_setup = {},
  system_open = {
    cmd = nil,
    args = {},
  },
  diagnostics = {
    enable = false,
    show_on_dirs = false,
    icons = {
      hint = "",
      info = "",
      warning = "",
      error = "",
    },
  },
  filters = {
    dotfiles = false,
    custom = {},
    exclude = {},
  },
  git = {
    enable = true,
    ignore = true,
    timeout = 400,
  },
  actions = {
    use_system_clipboard = true,
    change_dir = {
      enable = true,
      global = false,
      restrict_above_cwd = false,
    },
    open_file = {
      quit_on_open = true,
      resize_window = false,
      window_picker = {
        enable = true,
        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
        exclude = {
          filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
          buftype = { "nofile", "terminal", "help" },
        },
      },
    },
  },
  trash = {
    cmd = "trash",
    require_confirm = true,
  },
  log = {
    enable = false,
    truncate = false,
    types = {
      all = false,
      config = false,
      copy_paste = false,
      diagnostics = false,
      git = false,
      profile = false,
    },
  },
} -- END_DEFAULT_OPTSg

-- require('bufferline').setup {
--   options = {
--     mode = "buffers", -- set to "tabs" to only show tabpages instead
--     numbers = "none",
--     close_command = "q!",       -- can be a string | function, see "Mouse actions"
--     right_mouse_command = "q!", -- can be a string | function, see "Mouse actions"
--     left_mouse_command = "q!",    -- can be a string | function, see "Mouse actions"
--     middle_mouse_command = nil,          -- can be a string | function, see "Mouse actions"
--     -- NOTE: this plugin is designed with this icon in mind,
--     -- and so changing this is NOT recommended, this is intended
--     -- as an escape hatch for people who cannot bear it for whatever reason
--     indicator_icon = '',
--     buffer_close_icon = '',
--     modified_icon = '●',
--     close_icon = '',
--     left_trunc_marker = '',
--     right_trunc_marker = '',
--     --- name_formatter can be used to change the buffer's label in the bufferline.
--     --- Please note some names can/will break the
--     --- bufferline so use this at your discretion knowing that it has
--     --- some limitations that will *NOT* be fixed.
--     name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
--       -- remove extension from markdown files for example
--       if buf.name:match('%.md') then
--         return vim.fn.fnamemodify(buf.name, ':t:r')
--       end
--     end,
--     max_name_length = 40,
--     max_prefix_length = 15, -- prefix used when a buffer is de-duplicated
--     tab_size = 20,
--     diagnostics = "coc",
--     diagnostics_update_in_insert = false,
--   	diagnostics_indicator = function(count, level, diagnostics_dict, context)
--       local icon = level:match("error") and " " or " "
--       return " " .. icon .. count
--     end,
--     -- NOTE: this will be called a lot so don't do any heavy processing here
--     custom_filter = function(buf_number, buf_numbers)
--       -- filter out filetypes you don't want to see
--       if vim.bo[buf_number].filetype ~= "<i-dont-want-to-see-this>" then
--         return true
--       end
--       -- filter out by buffer name
--       if vim.fn.bufname(buf_number) ~= "<buffer-name-I-dont-want>" then
--         return true
--       end
--       -- filter out based on arbitrary rules
--       -- e.g. filter out vim wiki buffer from tabline in your work repo
--       if vim.fn.getcwd() == "<work-repo>" and vim.bo[buf_number].filetype ~= "wiki" then
--         return true
--       end
--       -- filter out by it's index number in list (don't show first buffer)
--       if buf_numbers[1] ~= buf_number then
--         return true
--       end
--     end,
--     color_icons = true, -- whether or not to add the filetype icon highlights
--     show_buffer_icons = true, -- disable filetype icons for buffers
--     show_buffer_close_icons = false,
--     show_buffer_default_icon = true, -- whether or not an unrecognised filetype should show a default icon
--     show_close_icon = false,
--     show_tab_indicators = true,
--     persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
--     -- can also be a table containing 2 custom separators
--     -- [focused and unfocused]. eg: { '|', '|' }
--     separator_style = "thin",
--     always_show_bufferline = true,
-- 	  }
-- }

