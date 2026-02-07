-- lua/java-creator-nvim/init.lua
local M = {}

-- Default configuration
M.config = {
	templates = {
		class = [[package %s;

public class %s {
    
}]],
		interface = [[package %s;

public interface %s {
    
}]],
		enum = [[package %s;

public enum %s {
    
}]],
		record = [[package %s;

public record %s() {
    
}]],
		abstract_class = [[package %s;

public abstract class %s {
    
}]],
	},

	default_imports = {
		class = {},
		interface = {},
		enum = {},
		record = { "java.util.*" },
		abstract_class = {},
	},

	keymaps = {
		java_new = "<leader>jn",
		java_class = "<leader>jc",
		java_interface = "<leader>ji",
		java_enum = "<leader>je",
		java_record = "<leader>jr",
	},

	options = {
		auto_open = true,
		use_notify = true, -- Set to false to disable all notifications from this plugin
		notification_timeout = 3000, -- Timeout for notifications in milliseconds
		java_version = 17,
		src_patterns = { "src/main/java", "src/test/java", "src" },
		project_markers = { "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", ".project" },
		custom_src_path = nil,
	},
}

local utils = {}

---
--- Sends a notification to the user if enabled in the config.
--- Uses 'nvim-notify' if available, otherwise falls back to vim.notify.
---
---@param msg string The message to display.
---@param level vim.log.levels The notification level (e.g., INFO, ERROR).
function utils.notify(msg, level)
	if not M.config.options.use_notify then
		return -- Do nothing if notifications are disabled
	end

	level = level or vim.log.levels.INFO

	local ok, notify_lib = pcall(require, "notify")
	if ok then
		-- Use 'nvim-notify' if available
		notify_lib(msg, level, {
			title = "Java Creator",
			timeout = M.config.options.notification_timeout,
		})
	else
		-- Fallback to the standard vim.notify
		vim.notify(msg, level)
	end
end

---
--- Displays an error message.
---
---@param msg string The error message.
function utils.error(msg)
	utils.notify(msg, vim.log.levels.ERROR)
end

---
--- Displays an informational message.
---
---@param msg string The info message.
function utils.info(msg)
	utils.notify(msg, vim.log.levels.INFO)
end

---
--- Displays a warning message.
---
---@param msg string The warning message.
function utils.warn(msg)
	utils.notify(msg, vim.log.levels.WARN)
end

---
--- Validates if a string is a valid Java identifier and not a keyword.
---
---@param name string The identifier to validate.
---@return boolean, string|nil True if valid, false and an error message otherwise.
function utils.validate_java_name(name)
	if not name or name == "" then
		return false, "Name cannot be empty"
	end
	if not name:match("^[a-zA-Z_]") then
		return false, "Name must start with a letter or underscore"
	end
	if not name:match("^[a-zA-Z0-9_]*$") then
		return false, "Name can only contain letters, numbers, and underscores"
	end

	local java_keywords = {
		"abstract",
		"assert",
		"boolean",
		"break",
		"byte",
		"case",
		"catch",
		"char",
		"class",
		"const",
		"continue",
		"default",
		"do",
		"double",
		"else",
		"enum",
		"extends",
		"final",
		"finally",
		"float",
		"for",
		"goto",
		"if",
		"implements",
		"import",
		"instanceof",
		"int",
		"interface",
		"long",
		"native",
		"new",
		"null",
		"package",
		"private",
		"protected",
		"public",
		"return",
		"short",
		"static",
		"strictfp",
		"super",
		"switch",
		"synchronized",
		"this",
		"throw",
		"throws",
		"transient",
		"try",
		"void",
		"volatile",
		"while",
		"true",
		"false",
	}

	for _, keyword in ipairs(java_keywords) do
		if name == keyword then
			return false, "Name cannot be a Java keyword: " .. keyword
		end
	end

	return true
end

---
--- Validates a Java package name.
---
---@param package string The package name to validate.
---@return boolean, string|nil True if valid, false and an error message otherwise.
function utils.validate_package_name(package)
	if package == "" or package == nil then
		return true -- Default package is valid
	end

	for part in package:gmatch("[^%.]+") do
		local valid, err = utils.validate_java_name(part)
		if not valid then
			return false, "Invalid package: " .. err
		end
	end
	return true
end

---
--- Finds the Java project root directory by searching for marker files.
---
---@param start_dir string|nil The directory to start searching from. Defaults to current working directory.
---@return string|nil The project root path or nil if not found.
function utils.find_java_project_root(start_dir)
	start_dir = start_dir or vim.fn.getcwd()
	local current_dir = start_dir

	while current_dir ~= "/" and current_dir ~= "" do
		for _, marker in ipairs(M.config.options.project_markers) do
			local marker_path = current_dir .. "/" .. marker
			if vim.fn.filereadable(marker_path) == 1 or vim.fn.isdirectory(marker_path) == 1 then
				return current_dir
			end
		end
		current_dir = vim.fn.fnamemodify(current_dir, ":h")
	end
	return nil
end

---
--- Finds the primary source directory (e.g., 'src/main/java') within a project.
---
---@param project_root string The project root path.
---@return string|nil The source directory path or nil if not found.
function utils.find_java_src_dir(project_root)
	if not project_root then
		return nil
	end

	if M.config.options.custom_src_path then
		local custom_path = project_root .. "/" .. M.config.options.custom_src_path
		if vim.fn.isdirectory(custom_path) == 1 then
			return custom_path
		end
	end

	-- Explicit list of candidate paths, ordered by specificity
	local candidates = {}
	for _, pattern in ipairs(M.config.options.src_patterns) do
		table.insert(candidates, project_root .. "/" .. pattern)
		table.insert(candidates, project_root .. "/backend/" .. pattern)
	end

	for _, candidate in ipairs(candidates) do
		if vim.fn.isdirectory(candidate) == 1 then
			return candidate
		end
	end

	return nil
end

---
--- Gets the base source directory for packages.
---
---@return string|nil The base package path or nil if not found.
function utils.get_package_base()
	local project_root = utils.find_java_project_root()
	if not project_root then
		return nil
	end
	return utils.find_java_src_dir(project_root)
end

---
--- Finds all available packages within the source directory.
---
---@return table A sorted list of all found package names.
function utils.find_available_packages()
	local src_dir = utils.get_package_base()
	if not src_dir then
		return {}
	end

	local packages = {}
	local dirs = vim.fn.glob(src_dir .. "/**/", false, true)

	for _, dir in ipairs(dirs) do
		if dir:sub(1, #src_dir) == src_dir then
			local relative = dir:sub(#src_dir + 2, -2)
			if relative ~= "" then
				local package_name = relative:gsub("/", ".")
				table.insert(packages, package_name)
			end
		end
	end

	table.sort(packages, function(a, b)
		return #a < #b -- Sort by increasing length
	end)

	return packages
end

---
--- Tries to determine the default package based on the current directory or open files.
---
---@return string The determined default package name.
function utils.find_default_package()
	local src_dir = utils.get_package_base()
	if not src_dir then
		return ""
	end

	local current_dir = vim.fn.getcwd()

	if current_dir:sub(1, #src_dir) == src_dir then
		local relative_path = current_dir:sub(#src_dir + 2)
		return relative_path:gsub("/", ".")
	end

	local java_files = vim.fn.glob(current_dir .. "/*.java", false, true)
	for _, file in ipairs(java_files) do
		local package = utils.extract_package_from_file(file)
		if package then
			return package
		end
	end

	return ""
end

---
--- Extracts the package declaration from a Java file.
---
---@param file string The path to the Java file.
---@return string|nil The package name or nil if not found.
function utils.extract_package_from_file(file)
	local content = utils.read_file(file)
	if content then
		local package_match = content:match("package%s+([^;]+);")
		return package_match
	end
	return nil
end

---
--- Reads the entire content of a file.
---
---@param file string The path to the file.
---@return string|nil The file content or nil on failure.
function utils.read_file(file)
	local f = io.open(file, "r")
	if not f then
		return nil
	end
	local content = f:read("*all")
	f:close()
	return content
end

---
--- Generates the full file path for a new Java file.
---
---@param package string The package name.
---@param name string The class/interface/enum name.
---@return string The generated file path.
function utils.generate_file_path(package, name)
	local src_dir = utils.get_package_base() or vim.fn.getcwd()

	if package and package ~= "" then
		local package_path = package:gsub("%.", "/")
		local full_dir = src_dir .. "/" .. package_path

		-- Create all directories in the package path recursively
		local parts = vim.split(package_path, "/")
		local current_path = src_dir
		for _, part in ipairs(parts) do
			current_path = current_path .. "/" .. part
			if vim.fn.isdirectory(current_path) == 0 then
				vim.fn.mkdir(current_path, "p")
			end
		end

		return full_dir .. "/" .. name .. ".java"
	else
		return src_dir .. "/" .. name .. ".java"
	end
end

---
--- Generates the content for a new Java file from a template.
---
---@param java_type string The type of Java file.
---@param package string The package name.
---@param name string The class/interface/enum name.
---@return string|nil, string|nil The file content, or nil and an error message.
function utils.generate_file_content(java_type, package, name)
	local template = M.config.templates[java_type]
	if not template then
		return nil, "Template not found for type: " .. java_type
	end

	-- Build the package declaration
	local package_line = ""
	if package and package ~= "" then
		package_line = "package " .. package .. ";\n\n"
	end

	-- Build import lines
	local imports = M.config.default_imports[java_type] or {}
	local import_lines = ""
	if #imports > 0 then
		for _, import in ipairs(imports) do
			import_lines = import_lines .. "import " .. import .. ";\n"
		end
		import_lines = import_lines .. "\n"
	end

	-- Fill the template with the actual package and name
	-- Templates use %s for package and %s for name
	local body
	if package and package ~= "" then
		body = string.format(template, package, name)
		-- Replace the package line from the template with our version that includes imports
		body = body:gsub("^package " .. package:gsub("%.", "%%.") .. ";\n\n", package_line .. import_lines)
	else
		-- Remove the package declaration from the template output
		body = string.format(template, "", name)
		body = body:gsub("^package ;\n\n", import_lines)
	end

	return body
end

local input = {}

---
--- Prompts the user to select a Java type.
---
---@param callback function The function to call with the selected type.
function input.get_java_type(callback)
	local types = { "class", "interface", "enum", "record", "abstract_class" }
	local type_labels = {
		class = "Class",
		interface = "Interface",
		enum = "Enum",
		record = "Record" .. (M.config.options.java_version < 16 and " (Java 16+)" or ""),
		abstract_class = "Abstract Class",
	}

	vim.ui.select(types, {
		prompt = "Select Java type:",
		format_item = function(item)
			return type_labels[item] or item
		end,
	}, callback)
end

---
--- Prompts the user for a string input.
---
---@param prompt string The prompt message.
---@param default string|nil The default value.
---@param callback function The function to call with the user's input.
function input.get_string(prompt, default, callback)
	vim.ui.input({
		prompt = prompt,
		default = default or "",
	}, callback)
end

---
--- Prompts the user to select or create a package.
---
---@param prompt string The prompt message.
---@param default string The default package.
---@param callback function The function to call with the selected package.
function input.get_package(prompt, default, callback)
	local src_dir = utils.get_package_base()
	local available_packages = utils.find_available_packages()

	vim.ui.select({ "(new package)", unpack(available_packages) }, {
		prompt = prompt,
		default = default,
		format_item = function(item)
			return item == "(new package)" and "✏️ " .. item or "📦 " .. item
		end,
	}, function(choice)
		if not choice then
			return callback(nil) -- Cancel operation
		end

		if choice == "(new package)" then
			vim.ui.select(available_packages, {
				prompt = "Select base package:",
				format_item = function(pkg)
					return "✏️ " .. pkg
				end,
			}, function(selected_pkg)
				if not selected_pkg then
					return callback(nil) -- Cancel operation
				end

				vim.ui.input({
					prompt = "New package: ",
					default = selected_pkg or "",
					completion = function(arg_lead)
						local matches = {}
						for _, p in ipairs(available_packages) do
							if p:find(arg_lead, 1, true) == 1 then
								table.insert(matches, p)
							end
						end
						return matches
					end,
				}, function(input_text)
					if not input_text then
						return callback(nil) -- Cancel operation
					end
					callback(input_text)
				end)
			end)
		else
			callback(choice)
		end
	end)
end

---
---
--- Creates the Java file after validating inputs.
---
---@param java_type string The type of Java file.
---@param name string The class/interface/enum name.
---@param package string The package name.
function M.create_java_file(java_type, name, package)
	if java_type == "record" and M.config.options.java_version < 16 then
		utils.error("Records require Java 16 or higher. Current version: " .. M.config.options.java_version)
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

	if M.config.options.auto_open then
		vim.cmd.edit(vim.fn.fnameescape(file_path))
	end

	utils.info(string.format("Created %s: %s", java_type, file_path))
end

---
--- Main interactive function to create a new Java file.
--- It guides the user through selecting type, name, and package.
---
function M.java_new()
	input.get_java_type(function(java_type)
		if not java_type then
			utils.info("Java file creation canceled.")
			return
		end

		input.get_string("Name for " .. java_type .. ": ", "", function(name)
			if not name then
				utils.info("Java file creation canceled.")
				return
			end
			if name == "" then
				utils.error("Name is required.")
				return
			end

			local default_package = utils.find_default_package()
			input.get_package("Package: ", default_package, function(package)
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
	input.get_string("Name for " .. java_type .. ": ", "", function(name)
		if not name or name == "" then
			utils.error("Name is required.")
			return
		end

		local default_package = utils.find_default_package()
		input.get_package("Package: ", default_package, function(package)
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

---
--- Sets up the plugin, commands, and keymaps.
--- This is the main entry point for the user's configuration.
---
---@param opts table|nil User-provided configuration to override defaults.
function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	vim.api.nvim_create_user_command("JavaNew", M.java_new, { desc = "Create a new Java file interactively" })
	vim.api.nvim_create_user_command("JavaClass", M.java_class, { desc = "Create a new Java class" })
	vim.api.nvim_create_user_command("JavaInterface", M.java_interface, { desc = "Create a new Java interface" })
	vim.api.nvim_create_user_command("JavaEnum", M.java_enum, { desc = "Create a new Java enum" })
	vim.api.nvim_create_user_command("JavaRecord", M.java_record, { desc = "Create a new Java record" })

	if M.config.keymaps then
		local command_map = {
			java_new = "JavaNew",
			java_class = "JavaClass",
			java_interface = "JavaInterface",
			java_enum = "JavaEnum",
			java_record = "JavaRecord",
		}

		for cmd, keymap in pairs(M.config.keymaps) do
			if keymap and keymap ~= "" and command_map[cmd] then
				vim.keymap.set("n", keymap, "<cmd>" .. command_map[cmd] .. "<cr>", {
					desc = "Java Creator: " .. command_map[cmd],
				})
			end
		end
	end

	utils.info("Java Creator plugin loaded")
end

return M
