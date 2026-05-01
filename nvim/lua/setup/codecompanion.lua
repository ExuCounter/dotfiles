local present, codecompanion = pcall(require, "codecompanion")

if not present then
  return
end

    -- mcphub = {
    --   callback = "mcphub.extensions.codecompanion",
    --   opts = {
    --     show_result_in_chat = true,  -- Show mcp tool results in chat
    --     make_vars = true,            -- Convert resources to #variables
    --     make_slash_commands = true,  -- Add prompts as /slash commands
    --   }
    -- },

codecompanion.setup({})
