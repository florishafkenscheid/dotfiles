return {
    "nvim-tree/nvim-tree.lua",

    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },

    config = function()
        local nvim_tree = require("nvim-tree")
        local api = require("nvim-tree.api")

        nvim_tree.setup({
            filters = {
                dotfiles = false,
                git_clean = false,
                no_buffer = false,
            },

            disable_netrw = true,
            hijack_netrw = true,
            update_cwd = true,
            hijack_cursor = true,
            hijack_directories = {
                enable = true,
                auto_open = true,
            },

            git = {
                enable = true,
                ignore = false,
                timeout = 500,
            },

            view = {
                width = 30,
                side = "left",
                number = false,
                relativenumber = false,
            },

            renderer = {
                highlight_git = true,
                root_folder_modifier = ":t",
                icons = {
                    show = {
                        file = true,
                        folder = true,
                        folder_arrow = true,
                        git = true,
                    },
                    glyphs = {
                        default = "",
                        symlink = "",
                        git = {
                            unstaged = "",
                            staged = "S",
                            unmerged = "",
                            renamed = "➜",
                            deleted = "",
                            untracked = "U",
                            ignored = "◌",
                        },
                        folder = {
                            default = "",
                            open = "",
                            empty = "",
                            empty_open = "",
                            symlink = "",
                        },
                    },
                },
            },
        })

        local opts = { noremap = true, silent = true }

        -- Keybinds
        vim.keymap.set('n', '<leader>e', function () api.tree.toggle({find_file = true}) end, opts)
        vim.keymap.set('n', '<leader>F', function () api.tree.open() end, opts)
        vim.keymap.set('n', '<leader>]', function () api.tree.change_root_to_node() end, opts)

        -- Open on startup
        vim.api.nvim_create_autocmd("BufEnter", {
            callback = function()
                if vim.fn.argc() == 0 or vim.fn.isdirectory(vim.fn.argv()[1]) == 1 then
                    api.tree.open()
                end
            end,
            once = true,
        })
    end,
}
