-- lua/java-creator-nvim/init.lua
local config = require("java-creator-nvim.config")
local utils = require("java-creator-nvim.utils")
local ui = require("java-creator-nvim.ui")

local M = {}

-- Expose submodules for testability and extensibility
M._config = config
M._utils = utils
M._ui = ui

---
--- Creates the Java file after validating inputs.
---
---@param java_type string The type of Java file.
---@param name string The class/interface/enum name.
---@param package string The package name.
function M.create_java_file(java_type, name, package)
	if java_type == "record" and config.options.options.java_version < 16 then
		utils.error("Records require Java 16 or higher. Current version: " .. config.options.options.java_version)
		return
	end

	local valid, err = utils.validate_java_name(name)
	if not valid then
		utils.error("Invalid name: " .. err)
		return
	end

	valid, err = utils.validate_package_name(package)
	if not valid then
		utils.error("Invalid package: " .. err)
		return
	end

	local file_path = utils.generate_file_path(package, name)
	if vim.fn.filereadable(file_path) == 1 then
		utils.error("File already exists: " .. file_path)
		return
	end

	local content, err_msg = utils.generate_file_content(java_type, package, name)
	if not content then
		utils.error("Error generating content: " .. err_msg)
		return
	end

	local file = io.open(file_path, "w")
	if not file then
		utils.error("Could not create file: " .. file_path)
		return
	end

	file:write(content)
	file:close()

	if config.options.options.auto_open then
		vim.cmd.edit(vim.fn.fnameescape(file_path))
	end

	utils.info(string.format("Created %s: %s", java_type, file_path))
end

---
--- Main interactive function to create a new Java file.
--- It guides the user through selecting type, name, and package.
---
function M.java_new()
	ui.get_java_type(function(java_type)
		if not java_type then
			utils.info("Java file creation canceled.")
			return
		end

		ui.get_string("Name for " .. java_type .. ": ", "", function(name)
			if not name then
				utils.info("Java file creation canceled.")
				return
			end
			if name == "" then
				utils.error("Name is required.")
				return
			end

			local default_package = utils.find_default_package()
			ui.get_package("Package: ", default_package, function(package)
				if not package then
					utils.info("Java file creation canceled.")
					return
				end
				M.create_java_file(java_type, name, package)
			end)
		end)
	end)
end

---
--- Creates a specific Java type directly, asking only for name and package.
---
---@param java_type string The type of file to create (e.g., 'class').
function M.create_java_type_direct(java_type)
	ui.get_string("Name for " .. java_type .. ": ", "", function(name)
		if not name or name == "" then
			utils.error("Name is required.")
			return
		end

		local default_package = utils.find_default_package()
		ui.get_package("Package: ", default_package, function(package)
			if not package then
				utils.info("Java file creation canceled.")
				return
			end
			M.create_java_file(java_type, name, package)
		end)
	end)
end

--- Shortcut function to create a Java class.
function M.java_class()
	M.create_java_type_direct("class")
end

--- Shortcut function to create a Java interface.
function M.java_interface()
	M.create_java_type_direct("interface")
end

--- Shortcut function to create a Java enum.
function M.java_enum()
	M.create_java_type_direct("enum")
end

--- Shortcut function to create a Java record.
function M.java_record()
	M.create_java_type_direct("record")
end

--- Shortcut function to create a Java abstract class.
function M.java_abstract_class()
	M.create_java_type_direct("abstract_class")
end

---
--- Sets up the plugin, commands, and keymaps.
--- This is the main entry point for the user's configuration.
---
---@param opts table|nil User-provided configuration to override defaults.
function M.setup(opts)
	config.setup(opts)

	vim.api.nvim_create_user_command("JavaNew", M.java_new, { desc = "Create a new Java file interactively" })
	vim.api.nvim_create_user_command("JavaClass", M.java_class, { desc = "Create a new Java class" })
	vim.api.nvim_create_user_command("JavaInterface", M.java_interface, { desc = "Create a new Java interface" })
	vim.api.nvim_create_user_command("JavaEnum", M.java_enum, { desc = "Create a new Java enum" })
	vim.api.nvim_create_user_command("JavaRecord", M.java_record, { desc = "Create a new Java record" })
	vim.api.nvim_create_user_command("JavaAbstractClass", M.java_abstract_class, { desc = "Create a new Java abstract class" })

	if config.options.keymaps then
		local command_map = {
			java_new = "JavaNew",
			java_class = "JavaClass",
			java_interface = "JavaInterface",
			java_enum = "JavaEnum",
			java_record = "JavaRecord",
			java_abstract_class = "JavaAbstractClass",
		}

		for cmd, keymap in pairs(config.options.keymaps) do
			if keymap and keymap ~= "" and command_map[cmd] then
				vim.keymap.set("n", keymap, "<cmd>" .. command_map[cmd] .. "<cr>", {
					desc = "Java Creator: " .. command_map[cmd],
				})
			end
		end
	end
end

return M
