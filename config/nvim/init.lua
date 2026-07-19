---@diagnostic disable: undefined-global
--------------------
--    Keybinds    --
--------------------

local opts = { noremap = true, silent = true }
local keymap = vim.api.nvim_set_keymap

-- <leader> key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Enter = new line below
keymap("n", "<Enter>", "o<ESC>", opts)

-- Shift Enter = new line above
keymap("n", "<S-Enter>", "O<ESC>", opts)

-- Exit terminal mode easier
keymap("t", "<esc><esc>", "<c-\\><c-n>", opts)

--------------------
--    Options     --
--------------------

-- Disable netrw in favor of nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Tabs -> 2 spaces
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Horizontal separator
vim.opt.laststatus = 3

-- Enable 24-bit colour
vim.opt.termguicolors = true

-- Configure diagnostics
vim.diagnostic.config({
	virtual_text = {
		prefix = "",
		suffix = "\t",
		spacing = 4,
		source = "if_many",
		format = function(diagnostic)
			return diagnostic.message
		end,
	},
	signs = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
})

--------------------
--    Plugins     --
--------------------

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- load plugins
require("lazy").setup("blousy.lazy")

require("blousy.floaterminal")

--------------------
--  Colorscheme   --
--------------------
vim.cmd.colorscheme("dune")
