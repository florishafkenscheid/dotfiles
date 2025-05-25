return {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPre", "BufNewFile" }, -- Only load when opening a file

    build = ":TSUpdate", -- Update parsers on load

    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = {
                "lua",
                "c",
                "cpp",
                "rust",
                "go",
            },

            sync_install = false,

            auto_install = true, -- self explanatory
        })
    end,
}
