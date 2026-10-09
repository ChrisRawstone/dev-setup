return {
  -- override nvim-cmp and add cmp-emoji
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
    mapping = {
      ["<C-Space>"] = function()
        local snacks = require("snacks")
        snacks.toggle()
      end,
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      table.insert(opts.sources, { name = "emoji" })
    end,
  },
  {
    "github/copilot.vim",
  },
}
