return {
    "nvim-lualine/lualine.nvim",
    dependencies = { 'nvim-tree/nvim-web-devicons' },

    event = "VeryLazy",

    config = function()
        -- Color setup, matching my own dune theme
        local dune_lualine_theme = {
            normal = {
                a = {},
                b = {},
                c = {},
                x = {},
                y = {},
                z = {},
            },

            insert = {

            },

            visual = {

            },

            replace = {

            },

            cmmand = {

            },

            inactive = {

            }
        },



        require('lualine').setup({
            options = {

            },
            sections = {

            },
            inactive_secitons = {

            },
            tabline = {},
            extensions = {},
        })
    end,
}
