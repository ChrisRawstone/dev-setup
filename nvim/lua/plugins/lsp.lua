return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gdscript = {},
      },
      setup = {
        gdscript = function(_, opts)
          -- Use the native Neovim 0.11+ LSP API instead of lspconfig's legacy .setup()
          -- This ensures vim.lsp.enable() activates the server for filetype auto-attach
          vim.lsp.config("gdscript", {
            cmd = vim.lsp.rpc.connect("127.0.0.1", 6005),
            on_init = function(client, init_result)
              -- Guard against re-starting the pipe if it already exists (e.g. second Neovim window)
              local pipe = "/tmp/godot.pipe"
              if vim.fn.filereadable(pipe) == 0 then
                vim.fn.serverstart(pipe)
              end
            end,
          })
          vim.lsp.enable("gdscript")
          return true
        end,
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "gdscript", "godot_resource", "gdshader" },
    },
  },
}
