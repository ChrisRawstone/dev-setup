return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Disable the default Python LSPs from LazyVim extras
        basedpyright = { enabled = false },
        pyright = { enabled = false },
        -- Enable ty (Astral's Python type checker)
        ty = {},
      },
    },
  },
}
