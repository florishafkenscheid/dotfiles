return {
    "nvim-telescope/telescope.nvim",
    event = "VimEnter", -- So <C-f> actually works before Telescope is called
    cmd = "Telescope", -- Or load when needed

    dependencies = {
        "nvim-lua/plenary.nvim",
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },

    config = function()
        local telescope = require("telescope")
        local builtin = require("telescope.builtin")

        telescope.setup({
            defaults = {
                mappings = {
                    i = { -- Insert mode
                        ["<esc>"] = require('telescope.actions').close
                    },
                    n = { -- Normal mode

                    }
                }
            },

            extensions = {
                fzf = {
                    fuzzy = true,
                    override_generic_sorter = true,
                    override_file_sorter = true,
                    case_mode = "smart_case",
                },
            },
        })

        local opts = { noremap = true, silent = true }

        vim.keymap.set('n', '<C-f>', function () builtin.find_files({ hidden = true, no_ignore = true }) end, opts)
    end,
}
