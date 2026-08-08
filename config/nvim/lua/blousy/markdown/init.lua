local function toggle_preview()
    local preview = require("render-markdown.core.preview")
    local current = vim.api.nvim_get_current_buf()
    local source = preview.get(current) or current

    preview.open(source)
    vim.schedule(function()
        if vim.api.nvim_buf_is_valid(source) then
            require("render-markdown.core.manager").set_buf(source, false)
        end
    end)
end

return {
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        keys = {
            {
                "<C-S-p>",
                toggle_preview,
                ft = "markdown",
                desc = "Toggle Markdown preview",
            },
        },
        opts = {
            enabled = false,
            overrides = {
                preview = {
                    enabled = true,
                    anti_conceal = {
                        enabled = false,
                    },
                },
            },
            on = {
                attach = function(ctx)
                    local preview = require("render-markdown.core.preview")
                    local source = preview.get(ctx.buf)
                    if not source then
                        return
                    end

                    if vim.api.nvim_buf_is_valid(ctx.buf) then
                        local source_name = vim.api.nvim_buf_get_name(source)
                        if source_name ~= "" then
                            vim.api.nvim_buf_set_name(ctx.buf, source_name .. " [Preview]")
                        end
                    end

                    vim.schedule(function()
                        if vim.api.nvim_buf_is_valid(ctx.buf) then
                            local preview_window = vim.fn.bufwinid(ctx.buf)
                            local source_window = vim.fn.bufwinid(source)
                            if preview_window ~= -1 and source_window ~= -1 then
                                vim.fn.win_splitmove(preview_window, source_window, {
                                    vertical = false,
                                    rightbelow = true,
                                })
                            end
                            vim.api.nvim_exec_autocmds("BufEnter", { buffer = ctx.buf })
                        end
                    end)
                end,
            },
        },
    },
    {
        "3rd/image.nvim",
        ft = { "markdown" },
        build = false,
        opts = {
            backend = "kitty",
            processor = "magick_cli",
            integrations = {
                markdown = {
                    enabled = true,
                    clear_in_insert_mode = false,
                    download_remote_images = true,
                    only_render_image_at_cursor = false,
                    floating_windows = false,
                    filetypes = { "markdown" },
                },
            },
        },
    },
}
