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

local arrow_function = s(
  "aw",
  fmt(
    [[
const {} = ({}) => {{
  {}
}}
]],
    {
      i(1, "fn"),
      i(2, "props"),
      i(3, ""),
    }
  )
)

table.insert(snippets, arrow_function)

local console_log = s(
  "cl",
  fmt(
    [[
console.log({}, "DEBUG_MODE")
]],
    { i(1, "") }
  )
)

table.insert(snippets, console_log)

local component = s(
  "c",
  fmt(
    [[
const {} = ({}) => {{
  {}
  return <></>
}} 
]],
    {
      i(1, "Component"),
      i(2, "props"),
      i(3, ""),
    }
  )
)

table.insert(snippets, component)

local import = s(
  "i",
  fmt(
    [[
  import {{{}}} from "{}"
]],
    {
      i(1, ""),
      i(2, ""),
    }
  )
)

table.insert(snippets, import)

local import_from_schema = s(
  "is",
  fmt(
    [[
  import {{{}}} from "{}"
]],
    {
      i(1, ""),
      i(2, "graphql-tools/__generated__/schema"),
    }
  )
)

table.insert(snippets, import_from_schema)

return snippets, autosnippets
