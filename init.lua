--[[

=====================================================
----------------- Masterboxer's Neovim ---------------
=====================================================

--]]

-- ============================================================
-- SECTION 1: OPTIONS
-- ============================================================
do
  vim.loader.enable()

  -- Set <space> as the leader key (must happen before plugins load)
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  -- Set to true if you have a Nerd Font installed and selected in your terminal
  vim.g.have_nerd_font = false

  vim.o.hlsearch = true
  vim.o.number = true
  vim.o.relativenumber = true
  vim.o.mouse = 'a'
  vim.o.showmode = false

  -- Don't line-break in the middle of a word
  vim.o.linebreak = true

  -- Sync clipboard between OS and Neovim (deferred so it doesn't slow startup)
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

  vim.o.breakindent = true
  vim.o.undofile = true

  -- Case-insensitive searching UNLESS \C or a capital letter is used
  vim.o.ignorecase = true
  vim.o.smartcase = true

  vim.o.signcolumn = 'yes'
  vim.o.updatetime = 250
  vim.o.timeoutlen = 300

  vim.o.splitright = true
  vim.o.splitbelow = true

  -- Better completion experience for nvim-cmp
  vim.o.completeopt = 'menuone,noselect'

  vim.o.termguicolors = true

  vim.o.inccommand = 'split'
  vim.o.cursorline = true
  vim.o.scrolloff = 10
  vim.o.confirm = true
end

-- ============================================================
-- SECTION 2: KEYMAPS & AUTOCMDS
-- ============================================================
do
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic config & keymaps
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },
    virtual_text = true,
    virtual_lines = false,
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float { bufnr = bufnr, scope = 'cursor', focus = false }
      end,
    },
  }
  vim.keymap.set('n', '[d', function() vim.diagnostic.jump { count = -1, float = true } end,
    { desc = 'Go to previous diagnostic message' })
  vim.keymap.set('n', ']d', function() vim.diagnostic.jump { count = 1, float = true } end,
    { desc = 'Go to next diagnostic message' })
  vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })

  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Window navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

  -- Keep scroll centered
  vim.keymap.set('n', '<C-d>', '<C-d>zz', { noremap = true })
  vim.keymap.set('n', '<C-u>', '<C-u>zz', { noremap = true })

  -- Move by display line when wrapped
  vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
  vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

  -- Buffer management
  vim.keymap.set('n', '<leader>bc', '<cmd>%bd|e#<CR>', { desc = 'Close All But Current' })
  vim.keymap.set('n', '<leader>bb', '<cmd>bd<CR>', { desc = 'Delete Current Buffer' })
  vim.keymap.set('n', '<leader>ba', '<cmd>%bd<CR>', { desc = 'Delete All Buffers' })
  vim.keymap.set('n', '<leader>dm', '<cmd>delmarks!<CR>:delmarks A-Z0-9<CR>', { desc = 'Delete All Marks' })

  -- Highlight when yanking (copying) text
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })

  -- [[ Git root helpers ]]
  ---@return string
  local function find_git_root()
    local current_file = vim.api.nvim_buf_get_name(0)
    local current_dir = current_file == '' and vim.fn.getcwd() or vim.fn.fnamemodify(current_file, ':h')

    local git_root = vim.fn.systemlist('git -C ' .. vim.fn.escape(current_dir, ' ') .. ' rev-parse --show-toplevel')[1]
    if vim.v.shell_error ~= 0 then
      print 'Not a git repository. Using current working directory'
      return vim.fn.getcwd()
    end
    return git_root
  end
  -- Exposed for other sections (telescope live-grep-git-root, toggleterm root terminal)
  _G.MasterboxerFindGitRoot = find_git_root

  vim.keymap.set('n', '<leader>tr', function()
    local git_root = find_git_root()
    vim.cmd('cd ' .. vim.fn.fnameescape(git_root))
    vim.cmd 'terminal'
    vim.cmd 'startinsert'
  end, { desc = 'Open Terminal In Root Directory' })
end

-- ============================================================
-- SECTION 3: PLUGIN MANAGER (vim.pack) & BUILD HOOKS
-- ============================================================
do
  local function run_build(name, cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd }):wait()
    if result.code ~= 0 then
      local output = (result.stderr ~= '' and result.stderr) or result.stdout or ''
      if output == '' then output = 'No output from build command.' end
      vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
    end
  end

  vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
      local name = ev.data.spec.name
      local kind = ev.data.kind
      if kind ~= 'install' and kind ~= 'update' then return end

      if name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
        run_build(name, { 'make' }, ev.data.path)
        return
      end

      if name == 'LuaSnip' then
        if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then
          run_build(name, { 'make', 'install_jsregexp' }, ev.data.path)
        end
        return
      end

      if name == 'nvim-treesitter' then
        if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
        vim.cmd 'TSUpdate'
        return
      end

      if name == 'go.nvim' then
        vim.cmd [[silent! lua require("go.install").update_all_sync()]]
        return
      end
    end,
  })
end

---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- SECTION 4: THEME, STATUSLINE & CORE UX
-- ============================================================
do
  vim.pack.add { gh 'folke/tokyonight.nvim' }
  vim.cmd.colorscheme 'tokyonight-night'
  vim.cmd.hi 'Comment gui=none'

  vim.pack.add { gh 'nvim-lualine/lualine.nvim' }
  require('lualine').setup {
    options = {
      icons_enabled = true,
      theme = 'horizon',
      component_separators = '|',
      section_separators = '',
    },
    sections = { lualine_x = { 'filetype' } },
  }

  vim.pack.add { gh 'lukas-reineke/indent-blankline.nvim' }
  require('ibl').setup {}

  vim.pack.add { gh 'NvChad/nvim-colorizer.lua' }
  require('colorizer').setup {
    filetypes = { 'css', 'scss', 'sass', 'javascript', 'html', html = { mode = 'foreground' } },
  }

  vim.pack.add { gh 'numToStr/Comment.nvim' }
  ---@diagnostic disable-next-line: missing-fields
  require('Comment').setup {}

  vim.pack.add { gh 'folke/which-key.nvim' }
  require('which-key').setup {
    delay = 0,
    icons = { mappings = vim.g.have_nerd_font },
    spec = {
      { '<leader>s', group = '[S]earch',   mode = { 'n', 'v' } },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      { '<leader>g', group = '[G]it' },
      { '<leader>b', group = '[B]uffer' },
    },
  }

  vim.pack.add { gh 'chentoast/marks.nvim' }
  require('marks').setup {}

  vim.pack.add { gh 'sphamba/smear-cursor.nvim' }
  require('smear_cursor').setup {}

  vim.pack.add { gh 'm4xshen/autoclose.nvim' }
  require('autoclose').setup {}

  vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim', gh 'nvim-tree/nvim-web-devicons' }
  require('render-markdown').setup {}

  vim.pack.add { gh 'mg979/vim-visual-multi' }

  vim.pack.add { gh 'tpope/vim-sleuth' }

  vim.pack.add { gh 'stevearc/oil.nvim' }
  require('oil').setup {}
  vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
end

-- ============================================================
-- SECTION 5: GIT TOOLING
-- ============================================================
do
  vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
  require('gitsigns').setup {
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },
    on_attach = function(bufnr)
      local gs = require 'gitsigns'
      vim.keymap.set('n', '<leader>ho', gs.preview_hunk, { buffer = bufnr, desc = 'Preview Git Hunk' })
      vim.keymap.set('n', '<leader>hi', gs.preview_hunk_inline, { buffer = bufnr, desc = 'Preview Hunk Inline' })
      vim.keymap.set('n', '<leader>hn', function() gs.nav_hunk 'next' end, { buffer = bufnr, desc = 'Next Hunk' })
      vim.keymap.set('n', '<leader>hp', function() gs.nav_hunk 'prev' end, { buffer = bufnr, desc = 'Previous Hunk' })
      vim.keymap.set('n', '<leader>hb', function() gs.blame_line { full = true } end,
        { buffer = bufnr, desc = 'Show Previous Git Changes' })

      -- Don't override built-in / fugitive keymaps
      vim.keymap.set({ 'n', 'v' }, ']c', function()
        if vim.wo.diff then return ']c' end
        vim.schedule(function() gs.nav_hunk 'next' end)
        return '<Ignore>'
      end, { expr = true, buffer = bufnr, desc = 'Jump to next hunk' })
      vim.keymap.set({ 'n', 'v' }, '[c', function()
        if vim.wo.diff then return '[c' end
        vim.schedule(function() gs.nav_hunk 'prev' end)
        return '<Ignore>'
      end, { expr = true, buffer = bufnr, desc = 'Jump to previous hunk' })
    end,
  }

  vim.pack.add { gh 'tpope/vim-fugitive' }
  vim.keymap.set('n', '<leader>ga', '<cmd>diffget //2<CR>', { desc = '[D]iff Get Left' })
  vim.keymap.set('n', '<leader>gl', '<cmd>diffget //3<CR>', { desc = '[D]iff Get Right' })
  vim.keymap.set('n', '<leader>gm', '<cmd>Git blame<CR>', { desc = 'Toggle [F]ull Length Git Blame' })

  vim.pack.add { gh 'sindrets/diffview.nvim', gh 'nvim-tree/nvim-web-devicons' }
  vim.keymap.set('n', '<leader>ff', '<cmd>DiffviewFileHistory %<CR>', { desc = '[C]urrent File History' })
  vim.keymap.set('n', '<leader>fg', '<cmd>DiffviewFileHistory<CR>', { desc = '[G]lobal File History' })
  vim.keymap.set('n', '<leader>fc', '<cmd>DiffviewClose<CR>', { desc = '[C]lose File History' })

  vim.pack.add { gh 'APZelos/blamer.nvim' }
  vim.cmd 'highlight Blamer guifg=#F89B13'
  vim.keymap.set('n', '<leader>gb', '<cmd>BlamerToggle<CR>', { desc = 'Toggle [G]it Blamer' })
end

-- ============================================================
-- SECTION 6: TERMINALS & SEARCH-AND-REPLACE
-- ============================================================
do
  vim.pack.add { gh 'akinsho/toggleterm.nvim' }
  require('toggleterm').setup {
    size = 20,
    open_mapping = [[<c-\>]],
    hide_numbers = true,
    shade_filetypes = {},
    shade_terminals = true,
    shading_factor = 2,
    start_in_insert = true,
    insert_mappings = true,
    persist_size = true,
    direction = 'float',
    close_on_exit = true,
    shell = vim.o.shell,
    float_opts = {
      border = 'curved',
      winblend = 0,
      highlights = { border = 'Normal', background = 'Normal' },
    },
  }

  local Terminal = require('toggleterm.terminal').Terminal

  local function floating_opts()
    return {
      hidden = true,
      direction = 'float',
      float_opts = { border = 'curved', winblend = 0 },
      on_open = function(term)
        vim.cmd 'startinsert!'
        vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = term.bufnr, noremap = true, silent = true })
      end,
      on_close = function() vim.cmd 'startinsert!' end,
    }
  end

  local lazygit = Terminal:new(vim.tbl_deep_extend('force', floating_opts(), {
    cmd = 'lazygit',
    dir = 'git_dir',
    float_opts = { border = 'double' },
  }))

  local persistent_terminal = Terminal:new(floating_opts())
  local current_dir_terminal = Terminal:new(floating_opts())
  local root_terminal = Terminal:new(floating_opts())

  vim.keymap.set('n', '<leader>gg', function() lazygit:toggle() end, { desc = 'Toggle [L]azygit' })
  vim.keymap.set('n', '<leader>ft', function() persistent_terminal:toggle() end,
    { desc = 'Toggle [F]loating [T]erminal' })
  vim.keymap.set('n', '<leader>tc', function()
    local current_file = vim.api.nvim_buf_get_name(0)
    current_dir_terminal.dir = current_file ~= '' and vim.fn.fnamemodify(current_file, ':h') or vim.fn.getcwd()
    current_dir_terminal:toggle()
  end, { desc = 'Toggle Terminal in [C]urrent Directory' })
  vim.keymap.set('n', '<leader>tR', function()
    root_terminal.dir = _G.MasterboxerFindGitRoot()
    root_terminal:toggle()
  end, { desc = 'Toggle Terminal in [R]oot Directory' })

  vim.pack.add { gh 'nvim-pack/nvim-spectre', gh 'nvim-lua/plenary.nvim' }
  vim.keymap.set('n', '<leader>ss', function() require('spectre').toggle() end, { desc = 'Toggle Spectre' })
  vim.keymap.set('n', '<leader>sw', function() require('spectre').open_visual { select_word = true } end,
    { desc = 'Search current word' })
  vim.keymap.set('v', '<leader>sw', '<esc><cmd>lua require("spectre").open_visual()<CR>',
    { desc = 'Search current word' })
  vim.keymap.set('n', '<leader>sp', function() require('spectre').open_file_search { select_word = true } end,
    { desc = 'Search on current file' })

  -- live-server.nvim >= v0.2.0 dropped require('live-server').setup{} in favor of
  -- a vim.g global that must be set before the plugin loads.
  vim.g.live_server = {}
  vim.pack.add { { src = gh 'barrett-ruth/live-server.nvim' } }
end

-- ============================================================
-- SECTION 7: SEARCH & NAVIGATION (Telescope)
-- ============================================================
do
  ---@type (string|vim.pack.Spec)[]
  local telescope_plugins = {
    gh 'nvim-lua/plenary.nvim',
    gh 'nvim-telescope/telescope.nvim',
    gh 'nvim-telescope/telescope-ui-select.nvim',
  }
  if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end
  vim.pack.add(telescope_plugins)

  require('telescope').setup {
    defaults = {
      mappings = {
        i = { ['<C-u>'] = false, ['<C-d>'] = false },
      },
      file_ignore_patterns = { '.git/' },
    },
    pickers = {
      find_files = { hidden = true },
    },
    extensions = {
      ['ui-select'] = { require('telescope.themes').get_dropdown() },
    },
  }

  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'ui-select')

  local builtin = require 'telescope.builtin'

  vim.api.nvim_create_user_command('LiveGrepGitRoot', function()
    local git_root = _G.MasterboxerFindGitRoot()
    if git_root then builtin.live_grep { search_dirs = { git_root } } end
  end, {})

  vim.keymap.set('n', '<leader>?', builtin.oldfiles, { desc = '[?] Find recently opened files' })
  vim.keymap.set('n', '<leader><space>', function()
    builtin.buffers { sort_lastused = true, initial_mode = 'normal' }
  end, { desc = '[ ] Find existing buffers' })

  vim.keymap.set('n', '<leader>/', function()
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown { winblend = 10, previewer = false })
  end, { desc = '[/] Fuzzily search in current buffer' })

  vim.keymap.set('n', '<leader>gf', builtin.git_files, { desc = 'Search [G]it [F]iles' })
  vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sG', '<cmd>LiveGrepGitRoot<cr>', { desc = '[S]earch by [G]rep on Git Root' })
  vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })

  vim.keymap.set('n', '<leader>q', function() builtin.diagnostics { initial_mode = 'normal' } end,
    { desc = '[S]earch [A]ll [D]iagnostics' })
end

-- ============================================================
-- SECTION 8: TREESITTER
-- ============================================================
do
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  local parsers = {
    'c', 'cpp', 'go', 'lua', 'python', 'tsx', 'javascript', 'typescript',
    'vimdoc', 'vim', 'bash', 'markdown', 'markdown_inline', 'html',
  }
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    if not vim.treesitter.language.add(language) then return end
    vim.treesitter.start(buf, language)
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
    if has_indent_query then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match
      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'
      if vim.tbl_contains(installed_parsers, language) then
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        treesitter_try_attach(buf, language)
      end
    end,
  })
end

-- ============================================================
-- SECTION 9: LSP
-- ============================================================
do
  vim.pack.add { gh 'j-hui/fidget.nvim' }
  require('fidget').setup {}

  -- Single LspAttach autocmd handles keymaps for every language server,
  -- including gopls (via go.nvim) and dartls (via flutter-tools) -
  -- replaces the old duplicated On_attach + dart-filetype autocmd.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('masterboxer-lsp-attach', { clear = true }),
    callback = function(event)
      local map = function(keys, func, desc, mode)
        vim.keymap.set(mode or 'n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
      map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })

      map('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
      map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
      map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
      map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
      map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
      map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

      map('K', vim.lsp.buf.hover, 'Hover Documentation')
      map('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

      map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
      map('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
      map('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
      map('<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end,
        '[W]orkspace [L]ist Folders')

      vim.api.nvim_buf_create_user_command(event.buf, 'Format', function() vim.lsp.buf.format() end,
        { desc = 'Format current buffer with LSP' })

      -- Document highlight on cursor hold
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        local hl_group = vim.api.nvim_create_augroup('masterboxer-lsp-highlight', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = hl_group,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = hl_group,
          callback = vim.lsp.buf.clear_references,
        })
        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('masterboxer-lsp-detach', { clear = true }),
          callback = function(event2)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds { group = 'masterboxer-lsp-highlight', buffer = event2.buf }
          end,
        })
      end

      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        map('<leader>th',
          function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end,
          '[T]oggle Inlay [H]ints')
      end
    end,
  })

  ---@type table<string, vim.lsp.Config>
  local servers = {
    ts_ls = {},
    eslint = {},
    html = { filetypes = { 'html', 'twig', 'hbs' } },
    angularls = {},
    lua_ls = {
      settings = {
        Lua = {
          workspace = { checkThirdParty = false },
          telemetry = { enable = false },
        },
      },
    },
  }

  vim.pack.add {
    gh 'neovim/nvim-lspconfig',
    gh 'mason-org/mason.nvim',
    gh 'mason-org/mason-lspconfig.nvim',
    gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  }

  require('mason').setup {}
  require('mason-lspconfig').setup { automatic_enable = false }
  require('mason-tool-installer').setup { ensure_installed = vim.tbl_keys(servers) }

  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end

  -- Extra Lua editing niceties for the Neovim config itself
  vim.pack.add { gh 'folke/lazydev.nvim' }
  require('lazydev').setup {}
end

-- ============================================================
-- SECTION 10: FORMATTING (conform.nvim replaces null-ls/none-ls)
-- ============================================================
do
  vim.pack.add { gh 'stevearc/conform.nvim' }

  local is_windows = vim.fn.has 'win32' == 1 or vim.fn.has 'win64' == 1
  local prettier_cmd = is_windows and 'C:\\Users\\s0060400\\AppData\\Roaming\\npm\\prettier.cmd' or 'prettier'

  require('conform').setup {
    notify_on_error = false,
    format_on_save = { timeout_ms = 10000, lsp_format = 'fallback' },
    default_format_opts = { lsp_format = 'fallback' },
    formatters = {
      prettier = { command = prettier_cmd },
    },
    formatters_by_ft = {
      javascript = { 'prettier' },
      typescript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescriptreact = { 'prettier' },
      css = { 'prettier' },
      scss = { 'prettier' },
      html = { 'prettier' },
      json = { 'prettier' },
      jsonc = { 'prettier' },
      yaml = { 'prettier' },
      markdown = { 'prettier' },
    },
  }

  local function format_buffer() require('conform').format { async = true, lsp_format = 'fallback' } end
  vim.keymap.set({ 'n', 'v' }, '<leader>f', format_buffer, { desc = '[F]ormat buffer' })
  vim.keymap.set({ 'n', 'x' }, '<leader>mm', format_buffer, { desc = 'Format With Prettier/LSP' })
end

-- ============================================================
-- SECTION 11: AUTOCOMPLETE & SNIPPETS (nvim-cmp)
-- ============================================================
do
  vim.pack.add {
    gh 'hrsh7th/nvim-cmp',
    gh 'hrsh7th/cmp-nvim-lsp',
    gh 'L3MON4D3/LuaSnip',
    gh 'saadparwaiz1/cmp_luasnip',
    gh 'rafamadriz/friendly-snippets',
  }

  local luasnip = require 'luasnip'
  require('luasnip.loaders.from_vscode').lazy_load()
  luasnip.config.setup {}

  local cmp = require 'cmp'
  cmp.setup {
    snippet = {
      expand = function(args) luasnip.lsp_expand(args.body) end,
    },
    completion = { completeopt = 'menu,menuone,noinsert' },
    mapping = cmp.mapping.preset.insert {
      ['<C-n>'] = cmp.mapping.select_next_item(),
      ['<C-p>'] = cmp.mapping.select_prev_item(),
      ['<C-d>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete {},
      ['<CR>'] = cmp.mapping.confirm { behavior = cmp.ConfirmBehavior.Replace, select = true },
      ['<Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expand_or_locally_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { 'i', 's' }),
      ['<S-Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.locally_jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { 'i', 's' }),
    },
    sources = {
      { name = 'nvim_lsp' },
      { name = 'luasnip' },
    },
  }
end

-- ============================================================
-- SECTION 12: LANGUAGE-SPECIFIC TOOLING (Go & Flutter/Dart)
-- ============================================================
do
  vim.pack.add { gh 'ray-x/go.nvim', gh 'ray-x/guihua.lua' }
  require('go').setup {}

  vim.pack.add {
    gh 'nvim-flutter/flutter-tools.nvim',
    gh 'stevearc/dressing.nvim',
  }
  require('flutter-tools').setup {
    lsp = { capabilities = require('cmp_nvim_lsp').default_capabilities() },
  }
end

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
