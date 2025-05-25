return {
    "neovim/nvim-lspconfig",

    -- when to load
    event = "BufReadPre",

    -- load before this plugin
    dependencies = {
       "williamboman/mason.nvim",
       "nvim-treesitter/nvim-treesitter",
       -- "hrsh7th/nvim-cpm",
    },

    -- config, run after plugin loads
    config = function ()
        local lspconfig = require("lspconfig")
        local capabilities = vim.lsp.protocol.make_client_capabilities() -- Basic capabilities
        -- local capabilities = require("cmp_nvim_lsp).default_capabilities()

        -- define global on_attach, runs for every lsp client that attaches to a buffer
        local on_attach = function(client, bufnr)
	        local buf_set_keymap = vim.api.nvim_buf_set_keymap
	        local opts = { noremap = true, silent = true}

	        buf_set_keymap(bufnr, 'n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', '<leader>q', '<cmd>lua vim.diagnostic.set_loclist()<CR>', opts)
	        buf_set_keymap(bufnr, 'n', '<leader>f', '<cmd>lua vim.lsp.buf.format({ async = true })<CR>', opts)
        end
    end
}
