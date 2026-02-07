-- lua/java-creator-nvim/utils.lua
local config = require("java-creator-nvim.config")

local M = {}

---
--- Sends a notification to the user if enabled in the config.
--- Uses 'nvim-notify' if available, otherwise falls back to vim.notify.
---
---@param msg string The message to display.
---@param level vim.log.levels The notification level (e.g., INFO, ERROR).
function M.notify(msg, level)
	if not config.options.options.use_notify then
		return
	end

	level = level or vim.log.levels.INFO

	local ok, notify_lib = pcall(require, "notify")
	if ok then
		notify_lib(msg, level, {
			title = "Java Creator",
			timeout = config.options.options.notification_timeout,
		})
	else
		vim.notify(msg, level)
	end
end

---
--- Displays an error message.
---
---@param msg string The error message.
function M.error(msg)
	M.notify(msg, vim.log.levels.ERROR)
end

---
--- Displays an informational message.
---
---@param msg string The info message.
function M.info(msg)
	M.notify(msg, vim.log.levels.INFO)
end

---
--- Displays a warning message.
---
---@param msg string The warning message.
function M.warn(msg)
	M.notify(msg, vim.log.levels.WARN)
end

---
--- Validates if a string is a valid Java identifier and not a keyword.
---
---@param name string The identifier to validate.
---@return boolean, string|nil True if valid, false and an error message otherwise.
function M.validate_java_name(name)
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
function M.validate_package_name(package)
	if package == "" or package == nil then
		return true -- Default package is valid
	end

	for part in package:gmatch("[^%.]+") do
		local valid, err = M.validate_java_name(part)
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
function M.find_java_project_root(start_dir)
	start_dir = start_dir or vim.fn.getcwd()
	local current_dir = start_dir

	while current_dir ~= "/" and current_dir ~= "" do
		for _, marker in ipairs(config.options.options.project_markers) do
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
function M.find_java_src_dir(project_root)
	if not project_root then
		return nil
	end

	if config.options.options.custom_src_path then
		local custom_path = project_root .. "/" .. config.options.options.custom_src_path
		if vim.fn.isdirectory(custom_path) == 1 then
			return custom_path
		end
	end

	-- Explicit list of candidate paths, ordered by specificity
	local candidates = {}
	for _, pattern in ipairs(config.options.options.src_patterns) do
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
function M.get_package_base()
	local project_root = M.find_java_project_root()
	if not project_root then
		return nil
	end
	return M.find_java_src_dir(project_root)
end

---
--- Finds all available packages within the source directory.
---
---@return table A sorted list of all found package names.
function M.find_available_packages()
	local src_dir = M.get_package_base()
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
function M.find_default_package()
	local src_dir = M.get_package_base()
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
		local package = M.extract_package_from_file(file)
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
function M.extract_package_from_file(file)
	local content = M.read_file(file)
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
function M.read_file(file)
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
function M.generate_file_path(package, name)
	local src_dir = M.get_package_base() or vim.fn.getcwd()

	if package and package ~= "" then
		local package_path = package:gsub("%.", "/")
		local full_dir = src_dir .. "/" .. package_path

		-- Create directories recursively
		vim.fn.mkdir(full_dir, "p")

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
function M.generate_file_content(java_type, package, name)
	local template = config.options.templates[java_type]
	if not template then
		return nil, "Template not found for type: " .. java_type
	end

	-- Build the package declaration
	local package_line = ""
	if package and package ~= "" then
		package_line = "package " .. package .. ";\n\n"
	end

	-- Build import lines
	local imports = config.options.default_imports[java_type] or {}
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

return M
