return {
    "nvim-lualine/lualine.nvim",
    dependencies = { 'nvim-tree/nvim-web-devicons' },

    event = "VeryLazy",

    config = function()
        -- Color setup, matching my own dune theme
        local dune_lualine_theme = {
            normal = {
                a = { fg = '#000000', bg = '#D77F00' },
                b = { fg = '#BBBBBB', bg = 'none' },
                c = { fg = '#DDDDDD', bg = 'none' },
                x = { fg = '#BBBBBB', bg = 'none' },
                y = { fg = '#DDDDDD', bg = 'none' },
                z = { fg = '#000000', bg = '#D77F00' },
            },
            insert = {
                a = { fg = '#000000', bg = '#AA5F09' },
                z = { fg = '#000000', bg = '#D77F00' },
            },

            visual = {
                a = { fg = '#000000', bg = '#FFD700' },
                z = { fg = '#000000', bg = '#D77F00' },
            },

            replace = {
                a = { fg = '#000000', bg = '#FF0000' },
                z = { fg = '#000000', bg = '#D77F00' },
            },

            command = {
                a = { fg = '#000000', bg = '#6D6D78' },
                z = { fg = '#000000', bg = '#D77F00' },
            },

            inactive = {
                a = { fg = '#808080', bg = 'none' },
                b = { fg = '#606060', bg = 'none' },
                c = { fg = '#404040', bg = 'none' },
                x = { fg = '#404040', bg = 'none' },
                y = { fg = '#606060', bg = 'none' },
                z = { fg = '#808080', bg = 'none' },
            }
        }


        local git_blame = require('gitblame')
        require('lualine').setup({
            options = {
                theme = dune_lualine_theme,
            },
            sections = {
                lualine_a = {'mode'},
                lualine_b = {'branch', 'diff'},
                lualine_c = {
                    {
                        git_blame.get_current_blame_text,
                        cond = git_blame.is_blame_text_available
                    }
                },
                lualine_x = {'diagnostics', 'filetype'},
                lualine_y = {'filename'},
                lualine_z = {'location'},
            },
            inactive_sections = {

            },
            tabline = {},
            extensions = {
                "nvim-tree",
                "fzf",
            },
        })
    end,
}
