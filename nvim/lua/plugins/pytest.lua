return {
  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   branch = "main",
  --   version = false,
  --   build = function()
  --     local TS = require("nvim-treesitter.install")
  --     if not TS.get_installed then
  --       LayzVim.error("Please restart Neovim and run `:TSUpdate` to use the `nvim-treesitter` **main** branch.")
  --       return
  --     end
  --     LazyVim.treesitter.build(function()
  --       TS.update(nil, { summary = true })
  --     end)
  --   end,
  --   opts = {
  --     indent = { enable = true },
  --     highlight = { enable = true, additional_vim_regex_highlighting = false },
  --     folds = { enable = true },
  --     ensure_installed = { "python", "xml", "bash", "html", "json", "lua", "markdown", "toml", "vim", "yaml" },
  --   },
  -- },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
  },
  {
    "richardhapb/pytest.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
    config = function(_, opts)
      require("pytest").setup(opts)
    end,
  },
}
