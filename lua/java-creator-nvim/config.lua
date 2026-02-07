-- lua/java-creator-nvim/config.lua
local M = {}

-- Default configuration
M.defaults = {
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
		java_abstract_class = "<leader>ja",
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

-- Active configuration (populated by setup)
M.options = vim.deepcopy(M.defaults)

---
--- Merges user options with defaults.
---
---@param opts table|nil User-provided configuration.
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
