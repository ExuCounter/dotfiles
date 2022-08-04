local vimp = require("vimp")

vim.g.comfortable_motion_no_default_key_mappings = 1

vimp.nmap({ "silent" }, "C-u", ':lua require("neoscroll").scroll(-25, true, 200)<CR>')
vimp.nmap({ "silent" }, "C-d", ':lua require("neoscroll").scroll(25, true, 200)<CR>')
vimp.nmap({ "silent" }, "zt", ':lua require("neoscroll").zb(250)<CR>')
vimp.nmap({ "silent" }, "zb", ':lua require("neoscroll").zt(250)<CR>')
