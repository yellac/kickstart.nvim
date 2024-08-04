-- See `:help vim.lsp.start_client` for an overview of the supported `config` options.
local status, jdtls = pcall(require, 'jdtls')
if not status then
  return
end

-- Setup Workspace
local home = os.getenv 'HOME'
local workspace_path = home .. '/.local/share/nvim/jdtls-workspace/'
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
local workspace_dir = workspace_path .. project_name

-- Determine OS
local os_config = 'linux'
if vim.fn.has 'mac' == 1 then
  os_config = 'mac'
end

-- Setup Capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
local extendedClientCapabilities = jdtls.extendedClientCapabilities
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

-- Setup Testing and Debugging
local bundles = {}
local mason_path = vim.fn.glob(vim.fn.stdpath 'data' .. '/mason/')
vim.list_extend(bundles, vim.split(vim.fn.glob(mason_path .. 'packages/java-test/extension/server/*.jar'), '\n'))
vim.list_extend(bundles, vim.split(vim.fn.glob(mason_path .. 'packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar'), '\n'))

-- Debugging active configuration
-- local dap = require 'dap'
-- dap.configurations.java = {
--   {
--     type = 'java',
--     request = 'launch',
--     name = 'Launch Java',
--     projectName = project_name,
--     mainClass = '${file}',
--   },
-- }

local config = {
  -- The command that starts the language server
  -- See: https://github.com/eclipse/eclipse.jdt.ls#running-from-the-command-line
  cmd = {

    -- 💀
    'java', -- or '/path/to/java17_or_newer/bin/java'
    -- depends on if `java` is in your $PATH env variable and if it points to the right version.

    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=ALL',
    '-Xmx1g',
    '--add-modules=ALL-SYSTEM',
    '--add-opens',
    'java.base/java.util=ALL-UNNAMED',
    '--add-opens',
    'java.base/java.lang=ALL-UNNAMED',
    -- '-javaagent:" .. home .. "/.local/share/nvim/mason/packages/jdtls/lombok.jar',

    -- 💀
    '-jar',
    vim.fn.glob(home .. '/.local/share/nvim/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar'),
    -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                                       ^^^^^^^^^^^^^^
    -- Must point to the                                                     Change this to
    -- eclipse.jdt.ls installation                                           the actual version

    -- 💀
    '-configuration',
    home .. '/.local/share/nvim/mason/packages/jdtls/config_' .. os_config,
    -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^        ^^^^^^
    -- Must point to the                      Change to one of `linux`, `win` or `mac`
    -- eclipse.jdt.ls installation            Depending on your system.

    -- 💀
    -- See `data directory configuration` section in the README
    '-data',
    workspace_dir,
  },

  -- 💀
  -- This is the default if not provided, you can remove it. Or adjust as needed.
  -- One dedicated LSP server & client will be started per unique root_dir
  --
  -- vim.fs.root requires Neovim 0.10.
  -- If you're using an earlier version, use: require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew'}),
  root_dir = vim.fs.root(0, { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' }),
  capabilities = capabilities,

  -- Here you can configure eclipse.jdt.ls specific settings
  -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
  -- for a list of options
  settings = {
    java = {
      eclipse = {
        downloadSources = true,
      },
      configuration = {
        updateBuildConfiguration = 'interactive',
        runtimes = {
          {
            name = 'JavaSE-22',
            path = '~/.sdkman/candidates/java/22.0.1-tem',
          },
          {
            name = 'JavaSE-21',
            path = '~/.sdkman/candidates/java/21.0.3-tem',
          },
          {
            name = 'JavaSE-17',
            path = '~/.sdkman/candidates/java/17.0.11-tem',
          },
        },
      },
      maven = {
        downloadSources = true,
      },
      implementationsCodeLens = {
        enabled = true,
      },
      referencesCodeLens = {
        enabled = true,
      },
      references = {
        includeDecompiledSources = true,
      },
      inlayHints = {
        parameterNames = {
          enabled = 'all', -- literals, all, none
        },
      },
      format = {
        enabled = false,
      },
    },
    signatureHelp = { enabled = true },
    extendedClientCapabilities = extendedClientCapabilities,
  },

  -- Language server `initializationOptions`
  -- You need to extend the `bundles` with paths to jar files
  -- if you want to use additional eclipse.jdt.ls plugins.
  --
  -- See https://github.com/mfussenegger/nvim-jdtls#java-debug-installation
  --
  -- If you don't plan on using the debugger or other eclipse.jdt.ls plugins you can remove this
  inti_options = {
    bundles = bundles,
  },
}

config['on_attach'] = function()
  local _, _ = pcall(vim.lsp.codelens.refresh)
  require('jdtls').setup_dap { hotcodereplace = 'auto', config_overrides = {} }
  local status_ok, jdtls_dap = pcall(require, 'jdtls.dap')
  if status_ok then
    jdtls_dap.setup_dap_main_class_configs()
  end
end

vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
  pattern = { '*.java' },
  callback = function()
    local _, _ = pcall(vim.lsp.codelens.refresh)
  end,
})

-- local formatters = require 'lvim.lsp.null-ls.formatters'
-- formatters.setup {
--   { command = 'google_java_format', filetypes = { 'java' } },
-- }

-- This starts a new client & server,
-- or attaches to an existing client & server depending on the `root_dir`.
require('jdtls').start_or_attach(config)

local status_ok, which_key = pcall(require, 'which-key')
if not status_ok then
  return
end

local opts = {
  mode = 'n', -- NORMAL mode
  prefix = '<leader>',
  buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
  silent = true, -- use `silent` when creating keymaps
  noremap = true, -- use `noremap` when creating keymaps
  nowait = true, -- use `nowait` when creating keymaps
}

local vopts = {
  mode = 'v', -- VISUAL mode
  prefix = '<leader>',
  buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
  silent = true, -- use `silent` when creating keymaps
  noremap = true, -- use `noremap` when creating keymaps
  nowait = true, -- use `nowait` when creating keymaps
}

local mappings = {
  C = {
    name = 'Java',
    o = { "<Cmd>lua require'jdtls'.organize_imports()<CR>", 'Organize Imports' },
    v = { "<Cmd>lua require('jdtls').extract_variable()<CR>", 'Extract Variable' },
    c = { "<Cmd>lua require('jdtls').extract_constant()<CR>", 'Extract Constant' },
    t = { "<Cmd>lua require'jdtls'.test_nearest_method()<CR>", 'Test Method' },
    T = { "<Cmd>lua require'jdtls'.test_class()<CR>", 'Test Class' },
    u = { '<Cmd>JdtUpdateConfig<CR>', 'Update Config' },
  },
}

local vmappings = {
  C = {
    name = 'Java',
    v = { "<Esc><Cmd>lua require('jdtls').extract_variable(true)<CR>", 'Extract Variable' },
    c = { "<Esc><Cmd>lua require('jdtls').extract_constant(true)<CR>", 'Extract Constant' },
    m = { "<Esc><Cmd>lua require('jdtls').extract_method(true)<CR>", 'Extract Method' },
  },
}

which_key.register(mappings, opts)
which_key.register(vmappings, vopts)
