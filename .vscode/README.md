# VSCode Workspace Configuration

This directory contains VSCode workspace-specific settings for the FIPS Container Images project.

## Files

- **settings.json** - Workspace settings optimized for Docker, YAML, Shell scripts, and Markdown
- **extensions.json** - Recommended and unwanted extensions for this workspace
- **tasks.json** - Pre-configured tasks for building images and running validations

## Required Extensions

To work effectively on this project, install these extensions:

### Core Extensions
1. **Docker** (`ms-azuretools.vscode-docker`) - Dockerfile syntax and IntelliSense
2. **YAML** (`redhat.vscode-yaml`) - YAML syntax, validation, and GitHub Actions schema
3. **Shell Format** (`foxundermoon.shell-format`) - Shell script formatting
4. **ShellCheck** (`timonwong.shellcheck`) - Shell script linting

### Documentation
5. **Markdown All in One** (`yzhang.markdown-all-in-one`) - Markdown editing support
6. **Markdown Lint** (`davidanson.vscode-markdownlint`) - Markdown linting

### Git Tools
7. **GitLens** (`eamodio.gitlens`) - Enhanced Git capabilities
8. **Git Graph** (`mhutchie.git-graph`) - Git history visualization

### Utilities
9. **EditorConfig** (`editorconfig.editorconfig`) - Consistent coding styles
10. **Code Spell Checker** (`streetsidesoftware.code-spell-checker`) - Spell checking
11. **Todo Tree** (`gruntfuggly.todo-tree`) - Highlight TODO comments
12. **Better Comments** (`aaron-bond.better-comments`) - Improved comment highlighting

## How to Restrict VSCode to Only These Extensions

VSCode doesn't have a built-in way to disable all other extensions for a workspace, but you can achieve this using **Profiles**:

### Method 1: Using VSCode Profiles (Recommended)

1. **Create a new profile** for this project:
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
   - Type "Profiles: Create Profile"
   - Name it "FIPS Container Images"
   - Choose "Create from Current Profile" or "Empty Profile"

2. **Configure the profile:**
   - In the profile, disable all extensions
   - Enable only the extensions listed in `extensions.json`
   - VSCode will remember this profile for this workspace

3. **Associate the profile with this workspace:**
   - Open this workspace
   - Press `Ctrl+Shift+P`
   - Type "Profiles: Use Profile for Current Workspace"
   - Select "FIPS Container Images"

### Method 2: Manual Extension Management

1. Open Extensions view (`Ctrl+Shift+X`)
2. For each extension not listed in the recommendations:
   - Click the gear icon
   - Select "Disable (Workspace)"
3. Install and enable only the recommended extensions

### Method 3: Install Recommended Extensions Only

1. Open the Extensions view (`Ctrl+Shift+X`)
2. Type `@recommended` in the search box
3. Click "Install Workspace Recommended Extensions"
4. Manually disable other extensions for this workspace

## Quick Start

1. Open this project in VSCode
2. When prompted, click "Install Recommended Extensions"
3. Reload VSCode when installation completes
4. The workspace settings will automatically configure formatters and linters

## Available Tasks

Press `Ctrl+Shift+P` and type "Tasks: Run Task" to access:

- **Build All Docker Images** - Build all FIPS Dockerfiles in the project
- **Run FIPS Validation** - Execute FIPS compliance validation scripts
- **Check Shell Scripts** - Lint all shell scripts with ShellCheck
- **Lint YAML Files** - Validate GitHub Actions workflows

## File Associations

The workspace automatically recognizes:
- `fips-dockerfile` files as Dockerfiles
- `*.Dockerfile` as Dockerfiles
- `*.yml` and `*.yaml` as YAML with GitHub Actions schema support

## Format on Save

The workspace is configured to auto-format files on save:
- Dockerfiles → Docker extension formatter
- YAML → YAML extension formatter
- Shell scripts → Shell Format
- Markdown → Markdown All in One

## Troubleshooting

**Extensions not loading?**
- Check that you've installed all recommended extensions
- Reload VSCode window (`Ctrl+Shift+P` → "Reload Window")

**Formatters not working?**
- Verify the extension is enabled for this workspace
- Check that the file type is correctly detected (bottom right corner)

**Settings not applying?**
- Workspace settings override user settings
- Check `.vscode/settings.json` for configuration details