local treesitter = require("nvim-treesitter.configs")

treesitter.setup(
    {
        ensure_installed = "all", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
        highlight = {
            enable = true, -- false will disable the whole extensio
            additional_vim_regex_highlighting = false,
            use_languagetree = true
        },
        ignore_install = {"phpdoc"},
        auto_install = true,
        autotag = {
            enable = true
        },
        matchup = {
            enable = false
        },
        context_commentstring = {
            enable = true,
            enable_autocmd = false
        }
    }
)
