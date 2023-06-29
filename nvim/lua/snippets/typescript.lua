local ls = require "luasnip"
local s = ls.snippet
local sn = ls.snippet_node
local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local fmt = require("luasnip.extras.fmt").fmt

local snippets = {}
local autosnippets = {}

local type_declaration = s(
  "t",
  fmt(
    [[
type {} = {}
]],
    { i(1, "Name"), i(2, "number") }
  )
)

table.insert(snippets, type_declaration)

return snippets, autosnippets
