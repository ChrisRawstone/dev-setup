-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- -- local opts = { noremap = true, silent = true }
-- vim.keymap.set("n", "<leader>cen", vim.lsp.diagnostic.goto_next())
-- vim.keymap.set("n", "<leader>cep", vim.lsp.diagnostic.goto_prev())

vim.g.copilot_no_tab_map = true
vim.keymap.set("i", "<C-CR>", 'copilot#Accept("\\<CR>")', { expr = true, replace_keycodes = false })
vim.keymap.set("n", "<leader>sag", function()
  require("telescope.builtin").live_grep({
    additional_args = function(opts)
      return { "--hidden", "--no-ignore" }
    end,
  })
end, { desc = "Search All Grep (including hidden and ignored)" })
