-- tests/minimal_init.lua
-- Minimal init file for running tests with plenary
vim.opt.rtp:append(".")
vim.opt.rtp:append("../plenary.nvim")

vim.cmd("runtime plugin/plenary.vim")
