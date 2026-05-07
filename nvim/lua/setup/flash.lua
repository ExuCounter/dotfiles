local present, flash = pcall(require, "flash")

if not present then
  return
end

flash.setup {
  modes = {
    char = {
      enabled = true,
      jump_labels = true,
      multi_line = false,
    },
    search = {
      enabled = false,
    },
  },
}
