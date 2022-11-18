local present, hop = pcall(require, "hop")

if not present then
    return
end

hop.setup(
    {
        create_hl_autocmd = false,
        extend_visual = true
    }
)
