---@diagnostic disable: undefined-global
local colors = {
    -- PATCH_OPEN
Normal = {fg = "#FFFFFF", bg = "#000000"},
Boolean = {fg = "#F2870D"},
Character = {fg = "#A17345"},
ColorColumn = {fg = "#F2870D", bg = "#F2870D"},
VertSplit = {link = "ColorColumn"},
Comment = {fg = "#6D6D78", italic = true},
Conditional = {fg = "#AA5F09"},
Label = {link = "Conditional"},
Constant = {fg = "#F2870D"},
CurSearch = {bg = "#F2870D"},
CursorColumn = {},
CursorLine = {},
Debug = {fg = "#F2870D", bold = true},
Define = {fg = "#AA5F09"},
Delimiter = {fg = "#E8E7E3"},
Directory = {fg = "#F2870D"},
EndOfBuffer = {fg = "#573105"},
Error = {fg = "#E83030"},
Exception = {fg = "#E83030"},
Float = {fg = "#F2D85A"},
FloatBorder = {fg = "#F2870D"},
FloatTitle = {fg = "#F9C386"},
Function = {fg = "#F2870D"},
Identifier = {fg = "#E8E7E3"},
Ignore = {},
IncSearch = {fg = "#FFFFFF", bg = "#F2870D"},
Include = {fg = "#AA5F09"},
Keyword = {fg = "#AA5F09"},
LineNr = {fg = "#B8670A"},
LineNrAbove = {fg = "#794406", italic = true},
LineNrBelow = {link = "LineNrAbove"},
Macro = {fg = "#AA5F09"},
MatchParen = {fg = "#E8E7E3", bg = "#F2870D"},
ModeMsg = {fg = "#F2870D"},
MoreMsg = {link = "ModeMsg"},
NonText = {fg = "#2B2217"},
Number = {fg = "#F2D85A"},
Operator = {fg = "#E8E7E3"},
PreCondit = {fg = "#AA5F09"},
PreProc = {fg = "#AA5F09"},
Question = {fg = "#F2870D"},
QuickFixLine = {fg = "#F2870D"},
Repeat = {fg = "#AA5F09"},
Special = {fg = "#F2870D"},
SpecialChar = {fg = "#F2870D"},
SpecialComment = {fg = "#F2870D", bold = true, italic = true},
Statement = {fg = "#AA5F09"},
StatusLine = {},
StatusLineNC = {},
StorageClass = {fg = "#AA5F09"},
String = {fg = "#A17345"},
Structure = {fg = "#AA5F09"},
Tag = {fg = "#AA5F09"},
Todo = {fg = "#F2D85A", bold = true},
Type = {fg = "#AA5F09", bold = true},
Typedef = {fg = "#AA5F09"},
Underlined = {underline = true},
Visual = {bg = "#5C4E3D"},
Winseparator = {fg = "#A05908"},
    -- PATCH_CLOSE
    -- Added by me as needed
htmlEndTag = {link= "Function"},
}

vim.cmd("highlight clear")
vim.cmd("set t_Co=256")
vim.cmd("let g:colors_name='dune'")

for group, attrs in pairs(colors) do
    vim.api.nvim_set_hl(0, group, attrs)
end
