---@diagnostic disable: undefined-global
--------------------
--    Keybinds    --
--------------------

local opts = { noremap = true, silent = true }
local keymap = vim.api.nvim_set_keymap

-- <leader> key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Enter = new line below
keymap('n', '<Enter>', 'o<ESC>', opts)

-- Shift Enter = new line above
keymap('n', 'SHIFT<Enter>', 'O<ESC>', opts)

--------------------
--    Options     --
--------------------

-- Disable netrw in favor of nvim-tree
vim.g.loaded_netrw = 1
vim.g.loader_netrwPlugin = 1

-- Tabs -> 4 spaces
vim.opt.tabstop 	    = 4
vim.opt.shiftwidth 	    = 4
vim.opt.expandtab	    = true

-- Line numbers
vim.opt.number          = true
vim.opt.relativenumber  = true

-- Enable 24-bit colour
vim.opt.termguicolors = true

--------------------
--    Plugins     --
--------------------

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath
	})
end
vim.opt.rtp:prepend(lazypath)

-- load plugins
require("lazy").setup("blousy.lazy", {

})

--------------------
--  Colorscheme   --
--------------------
vim.cmd.colorscheme('dune')
