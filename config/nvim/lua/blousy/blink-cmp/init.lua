return {
  'saghen/blink.cmp',
  dependencies = 'rafamadriz/friendly-snippets',
  version = '1.*',
  build = 'cargo build --release',
  opts = {
    keymap = {
        preset = 'default',

        -- Navigation
        ['<Up>'] = { 'select_prev', 'fallback' },
        ['<Down>'] = { 'select_next', 'fallback' },

        -- Functionality
        ['<D-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
        ['<D-e>'] = { 'hide' },
        ['<return>'] = { 'select_and_accept', 'fallback' },

        ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
        ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
    },

    completion = {
      menu = {
        draw = {
          columns = {
            { "kind_icon", "label", "label_description", gap = 1 },
            { "kind" },
          },
        },
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
      },
    },

    signature = { enabled = true },

    sources = {
      default = { "lsp", "path", "snippets", "buffer" },

      per_filetype = {
        python = { "lsp", "snippets", "buffer" },
      },
    },
  },
  opts_extend = { "sources.default" }
}
