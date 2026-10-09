return {

  -- add any tools you want to have installed below
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "uv",
        "ruff",
        "isort",
        "black",
        "stylua",
        "shellcheck",
        "shfmt",
        "flake8",
        "ty",
        -- Go
        "gopls",
        "goimports",
        "gofumpt",
        "golangci-lint",
      },
    },
  },
}
