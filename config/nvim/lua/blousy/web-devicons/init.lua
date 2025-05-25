return {
    "nvim-tree/nvim-web-devicons",

    config = function()
        require("nvim-web-devicons").setup({
            -- Aesthetics
            color_icons = true;
            variant = "dark";

            override_by_filename = {
                [".gitignore"] = {
                    icon = "",
                    color = "#f1502f",
                    name = "Gitignore"
                }
            };

            -- enable default icons
            default = true;

            -- no unexpected icons
            strict = true;
        })
    end,
}
