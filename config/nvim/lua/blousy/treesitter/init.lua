return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate", -- Update parsers on load

    config = function()
        local treesitter = require("nvim-treesitter")
        local languages = {
            "lua",
            "c",
            "cpp",
            "rust",
            "go",
        }

        treesitter.setup({
            install_dir = vim.fn.stdpath("data") .. "/site",
        })

        if vim.fn.executable("tree-sitter") == 1 then
            treesitter.install(languages)
        end

        vim.api.nvim_create_autocmd("FileType", {
            callback = function(args)
                pcall(vim.treesitter.start, args.buf)
            end,
        })
    end,
}
