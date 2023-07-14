local present, bufferline = pcall(require, "bufferline")

if not present then
  return
end

bufferline.setup {
  options = {
    mode = "buffers",
    diagnostics = "none",
    show_buffer_close_icons = false,
    show_close_icon = false,
    indicator = { icon = "|", style = "icon" },
    tab_size = 15,
    filetype_exclude = { "dashboard", "lsp-installer", "help" },
    buftype_exclude = { "terminal" },
  },
  highlights = {
    indicator_selected = {
      fg = "#cb4b16",
    },
  },
}
