return {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    keys = {
        {
            "<C-f>",
            function()
                require("telescope.builtin").find_files({ hidden = true, no_ignore = true })
            end,
        },
        {
            "<C-g>",
            function()
                require("telescope").extensions.live_grep_args.live_grep_args()
            end,
        },
    },

    dependencies = {
        "nvim-lua/plenary.nvim",
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
        "nvim-telescope/telescope-live-grep-args.nvim",
    },

    config = function()
        local telescope = require("telescope")

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
        telescope.load_extension("fzf")
        telescope.load_extension("live_grep_args")
    end,
}
