return {
    "nvim-lualine/lualine.nvim",
    dependencies = { 'nvim-tree/nvim-web-devicons' },

    event = "VeryLazy",

    config = function()
        local palettes = {
            dune = {
                bg = "#000000",
                fg = "#DDDDDD",
                muted = "#BBBBBB",
                accent = "#D77F00",
                insert = "#AA5F09",
                visual = "#FFD700",
                replace = "#FF0000",
                command = "#6D6D78",
            },
            miasma = {
                bg = "#222222",
                fg = "#DFD4AF",
                muted = "#C09A6B",
                accent = "#78834B",
                insert = "#5F875F",
                visual = "#C9A554",
                replace = "#B36D43",
                command = "#685742",
            },
        }
        local palette = palettes[vim.g.colors_name] or palettes.dune

        local desktop_lualine_theme = {
            normal = {
                a = { fg = palette.bg, bg = palette.accent },
                b = { fg = palette.muted, bg = palette.bg },
                c = { fg = palette.fg, bg = "none" },
                x = { fg = palette.muted, bg = "none" },
                y = { fg = palette.fg, bg = palette.bg },
                z = { fg = palette.bg, bg = palette.accent },
            },
            insert = {
                a = { fg = palette.bg, bg = palette.insert },
                z = { fg = palette.bg, bg = palette.accent },
            },

            visual = {
                a = { fg = palette.bg, bg = palette.visual },
                z = { fg = palette.bg, bg = palette.accent },
            },

            replace = {
                a = { fg = palette.bg, bg = palette.replace },
                z = { fg = palette.bg, bg = palette.accent },
            },

            command = {
                a = { fg = palette.bg, bg = palette.command },
                z = { fg = palette.bg, bg = palette.accent },
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

        ---@diagnostic disable: undefined-global
        vim.api.nvim_set_hl(0, "LualineSeparatorSpecial", {
            fg = palette.accent,
            bg = palette.bg,
        })

        local git_blame = require('gitblame')
        require('lualine').setup({
            options = {
                theme = desktop_lualine_theme,
                component_separators = { left = '', right = '' },
                section_separators = { left = '', right = '' },
            },
            sections = {
                lualine_a = { { 'mode', separator = { right = '' } } },
                lualine_b = { 'branch', 'diff' },
                lualine_c = {
                    {
                        git_blame.get_current_blame_text,
                        cond = git_blame.is_blame_text_available,
                        separator = { left = '%#LualineSeparatorSpecial#%*' }
                    }
                },
                lualine_x = {'diagnostics', 'filetype'},
                lualine_y = { { 'filename', separator = { left = '%#LualineSeparatorSpecial#╱%*', } } },
                lualine_z = { { 'location', separator = { left = '' } } },
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
