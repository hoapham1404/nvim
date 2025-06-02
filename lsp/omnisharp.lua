local os = require("utils.os")
local omnisharp_extended = require("omnisharp_extended")
local omnisharp_bin = ""

if os.is_linux() then
    omnisharp_bin = vim.fs.joinpath(vim.loop.os_homedir(), ".local", "bin", "omnisharp", "OmniSharp".."")
elseif os.is_windows() then
    omnisharp_bin = vim.fs.joinpath(vim.loop.os_homedir(), ".local", "bin", "omnisharp", "OmniSharp".."exe")
else
    vim.notify("Unsupported OS for omnisharp", vim.log.levels.ERROR)
    return
end

return {
    cmd = {
        omnisharp_bin,
        "-z",
        "--hostPID",
        tostring(vim.fn.getpid()),
        "DotNet:enablePackageRestore=false",
        "--encoding",
        "utf-8",
        "--languageserver",
    },
    filetypes = {"cs", "html", "vb"},
    root_markers = { '.sln', '.csproj', 'omnisharp.json', 'function.json' },
    init_options = {},
    capabilities = {
        workspace = {
            workspaceFolders = false, -- https://github.com/OmniSharp/omnisharp-roslyn/issues/909
        },
    },
    settings = {
        omnisharp = {
            enableImportCompletion = true,
            organizeImportsOnFormat = true,
            FormattingOptions = {
                -- Enables support for reading code style, naming convention and analyzer
                -- settings from .editorconfig.
                EnableEditorConfigSupport = true,
                -- Specifies whether 'using' directives should be grouped and sorted during
                -- document formatting.
                OrganizeImports = true,
            },
            MsBuild = {
                -- If true, MSBuild project system will only load projects for files that
                -- were opened in the editor. This setting is useful for big C# codebases
                -- and allows for faster initialization of code navigation features only
                -- for projects that are relevant to code that is being edited. With this
                -- setting enabled OmniSharp may load fewer projects and may thus display
                -- incomplete reference lists for symbols.
                LoadProjectsOnDemand = nil,
            },
            RoslynExtensionsOptions = {
                -- Enables support for roslyn analyzers, code fixes and rulesets.(nil/true)
                EnableAnalyzersSupport = true,
                -- Enables support for showing unimported types and unimported extension
                -- methods in completion lists. When committed, the appropriate using
                -- directive will be added at the top of the current file. This option can
                -- have a negative impact on initial completion responsiveness,
                -- particularly for the first few completion sessions after opening a
                -- solution.
                EnableImportCompletion = nil,
                -- Only run analyzers against open files when 'enableRoslynAnalyzers' is
                -- true
                AnalyzeOpenDocumentsOnly = nil,
                -- Enables the possibility to see the code in external nuget dependencies (nil/true)
                EnableDecompilationSupport = true,
            },
            RenameOptions = {
                RenameInComments = nil,
                RenameOverloads = nil,
                RenameInStrings = nil,
            },
            Sdk = {
                -- Specifies whether to include preview versions of the .NET SDK when
                -- determining which version to use for project loading.
                IncludePrereleases = true,
            },
        }
    }
}
