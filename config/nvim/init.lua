-- Neovim setup for reviewing Copilot CLI edits on Termux (VS Code-like)
vim.g.mapleader = " "
local o = vim.opt
o.number = true; o.relativenumber = false; o.mouse = "a"; o.termguicolors = true
o.signcolumn = "yes"; o.clipboard = "unnamedplus"; o.ignorecase = true; o.smartcase = true
o.splitright = true; o.splitbelow = true; o.wrap = false; o.updatetime = 250
o.expandtab = true; o.shiftwidth = 2; o.tabstop = 2; o.undofile = true
o.diffopt:append({ "algorithm:histogram", "linematch:60", "vertical" })

-- Auto-reload files changed on disk (by Copilot) -------------------------
o.autoread = true
local grp = vim.api.nvim_create_augroup("LiveReload", {})
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermLeave" }, {
  group = grp, command = "silent! checktime",
})
local timer = vim.uv.new_timer()
timer:start(1000, 1000, vim.schedule_wrap(function()
  if vim.fn.mode() ~= "c" then pcall(vim.cmd, "silent! checktime") end
end))
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = grp,
  callback = function(a)
    vim.notify("Reloaded: " .. vim.fn.fnamemodify(a.file, ":~:."), vim.log.levels.INFO)
    pcall(function() require("gitsigns").refresh() end)
  end,
})

-- Plugins (built-in vim.pack, nvim >= 0.12) -------------------------------
local gh = function(r) return "https://github.com/" .. r end
vim.pack.add({
  gh("folke/tokyonight.nvim"),
  gh("nvim-lua/plenary.nvim"),
  gh("MunifTanjim/nui.nvim"),
  gh("nvim-tree/nvim-web-devicons"),
  gh("nvim-neo-tree/neo-tree.nvim"),
  gh("lewis6991/gitsigns.nvim"),
  gh("sindrets/diffview.nvim"),
  gh("nvim-lualine/lualine.nvim"),
  gh("akinsho/bufferline.nvim"),
  gh("nvim-telescope/telescope.nvim"),
  gh("folke/which-key.nvim"),
  gh("kdheepak/lazygit.nvim"),
}, { confirm = false })

local ok = function(m) local s, r = pcall(require, m); return s and r end

pcall(vim.cmd.colorscheme, "tokyonight-night")

if ok("neo-tree") then
  require("neo-tree").setup({
    close_if_last_window = true,
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true, -- tree updates when files are created/changed
      filtered_items = { hide_dotfiles = false, hide_gitignored = false },
    },
    window = { width = 30 },
  })
end

if ok("gitsigns") then
  require("gitsigns").setup({
    current_line_blame = false,
    watch_gitdir = { follow_files = true },
    on_attach = function(b)
      local gs = require("gitsigns")
      local m = function(l, r, d) vim.keymap.set("n", l, r, { buffer = b, desc = d }) end
      m("]c", function() gs.nav_hunk("next") end, "Next change")
      m("[c", function() gs.nav_hunk("prev") end, "Prev change")
      m("<leader>hp", gs.preview_hunk_inline, "Preview change inline")
      m("<leader>hr", gs.reset_hunk, "Revert change (hunk)")
      m("<leader>hs", gs.stage_hunk, "Stage/accept hunk")
      m("<leader>hR", gs.reset_buffer, "Revert whole file")
      m("<leader>hd", gs.diffthis, "Diff this file")
      m("<leader>hw", gs.toggle_word_diff, "Toggle word diff")
    end,
  })
end

if ok("diffview") then
  require("diffview").setup({ enhanced_diff_hl = true, view = { merge_tool = { layout = "diff3_mixed" } } })
end
if ok("lualine") then require("lualine").setup({ options = { theme = "tokyonight", globalstatus = true } }) end
if ok("bufferline") then require("bufferline").setup({ options = { offsets = { { filetype = "neo-tree", text = "Explorer" } } } }) end
if ok("telescope") then require("telescope").setup({}) end
if ok("which-key") then require("which-key").setup({ delay = 300 }) end

-- Keymaps (Space = leader; press Space and wait for a menu) ---------------
local map = function(l, r, d) vim.keymap.set("n", l, r, { desc = d }) end
map("<leader>e", "<cmd>Neotree toggle<cr>", "File explorer")
map("<leader>gs", "<cmd>Neotree git_status toggle<cr>", "Changed files (Source Control)")
map("<leader>gd", "<cmd>DiffviewOpen<cr>", "Diff all changes (like VS Code SCM)")
map("<leader>gq", "<cmd>DiffviewClose<cr>", "Close diff view")
map("<leader>gh", "<cmd>DiffviewFileHistory %<cr>", "File history")
map("<leader>gg", "<cmd>LazyGit<cr>", "LazyGit")
map("<leader>ff", "<cmd>Telescope find_files<cr>", "Find file")
map("<leader>fg", "<cmd>Telescope live_grep<cr>", "Search text")
map("<leader>fb", "<cmd>Telescope buffers<cr>", "Open buffers")
map("<leader>fc", "<cmd>Telescope git_status<cr>", "Changed files picker")
map("<Tab>", "<cmd>BufferLineCycleNext<cr>", "Next tab")
map("<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", "Prev tab")
map("<leader>x", "<cmd>bdelete<cr>", "Close tab")
map("<leader>w", "<cmd>w<cr>", "Save")
map("<leader>q", "<cmd>qa<cr>", "Quit")
map("<leader>u", "<cmd>lua vim.pack.update()<cr>", "Update plugins")
