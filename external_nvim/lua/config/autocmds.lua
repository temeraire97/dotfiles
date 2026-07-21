-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- claudecode.nvim 터미널에서만 <C-q>로 터미널 모드를 빠져나가 이전(에디터) 창으로 포커스 이동
vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("claudecode_term_keymap", { clear = true }),
  callback = function(args)
    if vim.api.nvim_buf_get_name(args.buf):match("claude") then
      vim.keymap.set("t", "<C-q>", [[<C-\><C-n><C-w>p]], { buffer = args.buf, desc = "Focus editor window" })
    end
  end,
})
