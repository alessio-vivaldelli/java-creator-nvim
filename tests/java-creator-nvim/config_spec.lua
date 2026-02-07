-- tests/java-creator-nvim/config_spec.lua
local config = require("java-creator-nvim.config")

describe("config", function()
	before_each(function()
		config.setup({})
	end)

	it("has sensible defaults", function()
		assert.is_true(config.options.options.auto_open)
		assert.is_true(config.options.options.use_notify)
		assert.equals(17, config.options.options.java_version)
		assert.equals(3000, config.options.options.notification_timeout)
		assert.is_nil(config.options.options.custom_src_path)
	end)

	it("has all template types", function()
		assert.is_not_nil(config.options.templates.class)
		assert.is_not_nil(config.options.templates.interface)
		assert.is_not_nil(config.options.templates.enum)
		assert.is_not_nil(config.options.templates.record)
		assert.is_not_nil(config.options.templates.abstract_class)
	end)

	it("has default keymaps", function()
		assert.equals("<leader>jn", config.options.keymaps.java_new)
		assert.equals("<leader>jc", config.options.keymaps.java_class)
		assert.equals("<leader>ji", config.options.keymaps.java_interface)
		assert.equals("<leader>je", config.options.keymaps.java_enum)
		assert.equals("<leader>jr", config.options.keymaps.java_record)
		assert.equals("<leader>ja", config.options.keymaps.java_abstract_class)
	end)

	it("includes Gradle KTS in project markers", function()
		local markers = config.options.options.project_markers
		local has_gradle_kts = false
		local has_settings_kts = false
		for _, m in ipairs(markers) do
			if m == "build.gradle.kts" then
				has_gradle_kts = true
			end
			if m == "settings.gradle.kts" then
				has_settings_kts = true
			end
		end
		assert.is_true(has_gradle_kts)
		assert.is_true(has_settings_kts)
	end)

	it("merges user options with defaults", function()
		config.setup({
			options = {
				java_version = 21,
				auto_open = false,
			},
		})
		assert.equals(21, config.options.options.java_version)
		assert.is_false(config.options.options.auto_open)
		-- Other defaults should be preserved
		assert.is_true(config.options.options.use_notify)
		assert.equals(3000, config.options.options.notification_timeout)
	end)

	it("does not mutate defaults when merging", function()
		config.setup({ options = { java_version = 11 } })
		assert.equals(17, config.defaults.options.java_version)
	end)
end)
