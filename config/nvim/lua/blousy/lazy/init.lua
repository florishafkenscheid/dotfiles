return {
    -- LSP & Treesitter
    require("blousy.lspconfig"),
    require("blousy.mason"),
    require("blousy.mason-lspconfig"),
    require("blousy.treesitter"),

    -- Aesthetics
    require("blousy.lualine"),
    require("blousy.web-devicons"),
    require("blousy.virt-column"),
    -- require("blousy.lush"),

    -- File Browsing & Navigation
    require("blousy.nvim-tree"),
    require("blousy.telescope"),
}
