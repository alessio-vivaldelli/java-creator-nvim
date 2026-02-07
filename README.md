# java-creator.nvim

<!--toc:start-->
- [java-creator.nvim](#java-creatornvim)
  - [Features](#features)
  - [Demo](#demo)
    - [Create new class inside an existing package](#create-new-class-inside-an-existing-package)
    - [Create new class inside a new package](#create-new-class-inside-a-new-package)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Basic Commands](#basic-commands)
  - [Configuration](#configuration)
<!--toc:end-->

This plugin was created to help generate Java class files like in different IDEs, in an interactive way that allows you to choose which package to place it in and to create a new one if needed. When creating the file, it automatically sets the file's package so you don't have to do it manually.

## Features

- Supports:
  - Classes
  - Interfaces
  - Enums
  - Records (Java 16+)
  - Abstract classes
- Automatic package detection
- Check file/package name validity

## Demo

### Create new class inside an existing package

![New class](./res/new-class.gif)

### Create new class inside a new package

![New package](./res/new-package.gif)

## Installation

Using [Lazy.nvim](https://github.com/folke/lazy.nvim), with basic configuration:

```lua
{
  'alessio-vivaldelli/java-creator-nvim',
  ft = 'java',
  opts = {
    -- Default configuration
    keymaps = {
      java_new = "<leader>jn",
    },
    options = {
      auto_open = true,  -- Open file after creation
      java_version = 17  -- Minimum Java version
    }
  }
}
```

Suggested configuration is:

```lua
{
  {
    "alessio-vivaldelli/java-creator-nvim",
    config = function()
      require("java-creator-nvim").setup({
        options = {
          java_version = 17,
          auto_open = true,
          use_notify = true,
          custom_src_path = "backend/src/main/java",
          src_patterns = { "src/main/java", "src/test/java", "src" },
          project_markers = { "pom.xml", "build.gradle", "settings.gradle", ".project", "backend" },
          notification_timeout = 3000,
        },
        keymaps = {
          java_new = "<leader>jn",
          java_class = "<leader>jc",
          java_interface = "<leader>ji",
          java_enum = "<leader>je",
          java_record = "<leader>jr",
        },
        default_imports = {
          record = { "java.util.*" }, -- Import di default per i record
        },
      })

      vim.keymap.set("i", "<C-space>", 'pumvisible() ? "\\<C-n>" : "\\<C-x>\\<C-u>"', {
        expr = true,
        desc = "",
      })
    end,
    ft = "java",
    event = "VeryLazy",
    dependencies = {
      { "rcarriga/nvim-notify", optional = true },
    },
  },
}
```

## Usage

### Basic Commands

```vim
:JavaNew       " Interactive creation wizard
:JavaClass     " Create a new class
:JavaInterface " Create a new interface  
:JavaEnum      " Create a new enum
:JavaRecord    " Create a new record (Java 16+)
```

You can also set keymaps to bind this operation.

## Configuration

All configuration are:

```lua
  -- Customize templates for Java types
  templates = {
    class = [[package %s;

public class %s {
    // TODO: Implement class
}]],
    interface = [[package %s;

public interface %s {
    // TODO: Implement interface
}]],
    enum = [[package %s;

public enum %s {
    // TODO: Add enum values
}]],
    record = [[package %s;

public record %s() {
    // TODO: Add record components
}]],
    abstract_class = [[package %s;

public abstract class %s {
    // TODO: Implement abstract class
}]],
  },

  -- Default imports for each type
  default_imports = {
    record = { "java.util.*", "java.io.Serializable" },
    class = { "java.util.*" },
  },

  -- Custom key mappings
  keymaps = {
    java_new = "<leader>jn",      -- Interactive Java file creation
    java_class = "<leader>jc",    -- Create new class
    java_interface = "<leader>ji",-- Create new interface
    java_enum = "<leader>je",     -- Create new enum
    java_record = "<leader>jr",   -- Create new record
  },

  -- General options
  options = {
    auto_open = true,             -- Automatically open created file
    use_notify = true,           -- Use notifications (nvim-notify if available)
    notification_timeout = 3000, -- Notification timeout in milliseconds
    java_version = 17,           -- Target Java version
    src_patterns = {             -- Patterns to find source directories
      "src/main/java", 
      "src/test/java", 
      "src"
    },
    project_markers = {          -- Files that identify a Java project
      "pom.xml", 
      "build.gradle", 
      "settings.gradle", 
      ".project", 
      "backend"
    },
    custom_src_path = nil,       -- Custom source path (optional)
```

- **Templates**: Customize the initial content for different Java file types.
- **Default Imports**: Specify automatic imports for each file type.
- **Keymaps**: Customize keyboard shortcuts for quick file creation.
- **Options**:
  - `auto_open`: If true, automatically opens the created file.
  - `use_notify`: Shows notifications using nvim-notify or falls back to vim.notify.
  - `java_version`: Sets the target Java version (affects feature availability like records).
  - `src_patterns`: Directories where Java source files are searched.
  - `project_markers`: Files/directories that identify a Java project root.
