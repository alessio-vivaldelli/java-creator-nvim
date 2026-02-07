-- lua/java-creator-nvim/ui.lua
local config = require("java-creator-nvim.config")
local utils = require("java-creator-nvim.utils")

local M = {}

---
--- Prompts the user to select a Java type.
---
---@param callback function The function to call with the selected type.
function M.get_java_type(callback)
	local types = { "class", "interface", "enum", "record", "abstract_class" }
	local type_labels = {
		class = "Class",
		interface = "Interface",
		enum = "Enum",
		record = "Record" .. (config.options.options.java_version < 16 and " (Java 16+)" or ""),
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
function M.get_string(prompt, default, callback)
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
function M.get_package(prompt, default, callback)
	local available_packages = utils.find_available_packages()

	--- Helper to prompt for a new package name with completion.
	---@param default_value string The pre-filled value.
	local function prompt_new_package(default_value)
		vim.ui.input({
			prompt = "New package: ",
			default = default_value or "",
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
				return callback(nil)
			end
			callback(input_text)
		end)
	end

	-- If no packages exist yet, go straight to free-text input
	if #available_packages == 0 then
		return prompt_new_package(default)
	end

	vim.ui.select({ "(new package)", unpack(available_packages) }, {
		prompt = prompt,
		default = default,
		format_item = function(item)
			return item == "(new package)" and "✏️ " .. item or "📦 " .. item
		end,
	}, function(choice)
		if not choice then
			return callback(nil)
		end

		if choice == "(new package)" then
			vim.ui.select(available_packages, {
				prompt = "Select base package:",
				format_item = function(pkg)
					return "📦 " .. pkg
				end,
			}, function(selected_pkg)
				if not selected_pkg then
					return callback(nil)
				end
				prompt_new_package(selected_pkg)
			end)
		else
			callback(choice)
		end
	end)
end

return M
