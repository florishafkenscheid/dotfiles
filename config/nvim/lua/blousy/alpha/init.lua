return {
    "goolord/alpha-nvim",
    event = "VimEnter",

    config = function()
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")

        dashboard.section.header.val = {
            "    __    __                      ",
            "   / /_  / /___  __  _________  __",
            "  / __ \\/ / __ \\/ / / / ___/ / / /",
            " / /_/ / / /_/ / /_/ (__  ) /_/ / ",
            "/_.___/_/\\____/\\__,_/____/\\__, /  ",
            "                         /____/   ",
        }

        dashboard.section.buttons.val = {
            dashboard.button("f", "󰈞  > Find files", "<cmd>Telescope find_files hidden=true no_ignore=true<cr>"),
            dashboard.button("g", "󰍉  > Live grep", "<cmd>Telescope live_grep_args<cr>"),
            dashboard.button("e", "  > File tree", "<cmd>NvimTreeToggle<cr>"),
            dashboard.button("l", "󰒲  > Lazy", "<cmd>Lazy<cr>"),
            dashboard.button("q", "󰗼  > Quit", "<cmd>qa<cr>"),
        }

        dashboard.section.header.opts.hl = "AlphaHeader"
        dashboard.section.buttons.opts.hl = "AlphaButtons"

        vim.api.nvim_set_hl(0, "AlphaHeader", { link = "Title" })
        vim.api.nvim_set_hl(0, "AlphaButtons", { link = "Directory" })

        alpha.setup(dashboard.opts)
    end,
}
