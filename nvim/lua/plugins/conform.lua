return {
  {
    "stevearc/conform.nvim",
    -- opts = {
    --   formatters_by_ft = {
    --     python = { "isort", "ruff" },
    --   },
    -- },
    opts = {
      lua = { "stylua" },
      formatters_by_ft = {
        python = {
          -- To fix auto-fixable lint errors.
          "ruff_fix",
          -- To run the Ruff formatter.
          "ruff_format",
          -- To organize the imports.
          "ruff_organize_imports",
        },
      },
      -- Conform will run multiple formatters sequentially
      -- python = function(bufnr)
      --   if require("conform").get_formatter_info("ruff_format", bufnr).available then
      --     return { "ruff_format" }
      --   else
      --     return { "isort", "black" }
      --   end
      -- end,
      python = {},
      -- You can customize some of the format options for the filetype (:help conform.format)
      rust = { "rustfmt", lsp_format = "fallback" },
      -- Conform will run the first available formatter
      javascript = { "prettierd", "prettier", stop_after_first = true },
    },
  },
  -- {
  --   "mfussenegger/nvim-lint",
  --   opts = {
  --     linters_by_ft = {
  --       python = { "ruff" },
  --     },
  --   },
  -- },
}
