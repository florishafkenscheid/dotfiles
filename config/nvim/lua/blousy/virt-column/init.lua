return {
    "lukas-reineke/virt-column.nvim",
    event = "VimEnter",

    config = function()
        require("virt-column").setup({
            virtcolumn="100",

            exclude = {
                filetypes = {
                    "Lazy",
                    "help",
                    "man",
                    "gitcommit",
                    "TelescopePrompt",
                    "TelescopeResults",
                },

                buftypes = {
                    "terminal",
                },
            },
        })
    end,
}
