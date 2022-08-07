local M = {}

M["unload_lua_namespace"] = function(prefix)
    local prefix_with_ancestor = "^" .. prefix

    for key, _ in pairs(package.loaded) do
        if string.match(key, prefix_with_ancestor) then
            package.loaded[key] = nil
        end
    end
end

return M
