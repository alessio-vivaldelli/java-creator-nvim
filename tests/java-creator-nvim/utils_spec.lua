-- tests/java-creator-nvim/utils_spec.lua
local utils = require("java-creator-nvim.utils")
local config = require("java-creator-nvim.config")

describe("utils", function()
	before_each(function()
		config.setup({})
	end)

	describe("validate_java_name", function()
		it("rejects empty names", function()
			local valid, err = utils.validate_java_name("")
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)

		it("rejects nil names", function()
			local valid, err = utils.validate_java_name(nil)
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)

		it("rejects names starting with a number", function()
			local valid, err = utils.validate_java_name("1Foo")
			assert.is_false(valid)
			assert.matches("start with a letter", err)
		end)

		it("rejects names with special characters", function()
			local valid, err = utils.validate_java_name("Foo-Bar")
			assert.is_false(valid)
			assert.matches("only contain letters", err)
		end)

		it("rejects Java keywords (case-sensitive)", function()
			local valid, err = utils.validate_java_name("class")
			assert.is_false(valid)
			assert.matches("keyword", err)

			valid, err = utils.validate_java_name("public")
			assert.is_false(valid)
			assert.matches("keyword", err)
		end)

		it("accepts valid capitalized names that look like keywords", function()
			-- Java keywords are case-sensitive, so Class and Public are valid
			local valid = utils.validate_java_name("Class")
			assert.is_true(valid)

			valid = utils.validate_java_name("Public")
			assert.is_true(valid)

			valid = utils.validate_java_name("Interface")
			assert.is_true(valid)
		end)

		it("accepts valid names", function()
			assert.is_true(utils.validate_java_name("MyClass"))
			assert.is_true(utils.validate_java_name("_private"))
			assert.is_true(utils.validate_java_name("Foo123"))
			assert.is_true(utils.validate_java_name("A"))
		end)

		it("accepts names starting with underscore", function()
			assert.is_true(utils.validate_java_name("_test"))
			assert.is_true(utils.validate_java_name("__double"))
		end)
	end)

	describe("validate_package_name", function()
		it("accepts empty package (default package)", function()
			assert.is_true(utils.validate_package_name(""))
		end)

		it("accepts nil package", function()
			assert.is_true(utils.validate_package_name(nil))
		end)

		it("accepts valid single-segment package", function()
			assert.is_true(utils.validate_package_name("com"))
		end)

		it("accepts valid multi-segment package", function()
			assert.is_true(utils.validate_package_name("com.example.myapp"))
		end)

		it("rejects package with keyword segment", function()
			local valid, err = utils.validate_package_name("com.class.myapp")
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)

		it("rejects package with invalid segment", function()
			local valid, err = utils.validate_package_name("com.123.myapp")
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)
	end)

	describe("generate_file_content", function()
		it("generates class content with package", function()
			local content = utils.generate_file_content("class", "com.example", "MyClass")
			assert.is_not_nil(content)
			assert.matches("package com%.example;", content)
			assert.matches("public class MyClass", content)
		end)

		it("generates class content without package", function()
			local content = utils.generate_file_content("class", "", "MyClass")
			assert.is_not_nil(content)
			assert.is_nil(content:match("package"))
			assert.matches("public class MyClass", content)
		end)

		it("generates interface content", function()
			local content = utils.generate_file_content("interface", "com.example", "MyInterface")
			assert.is_not_nil(content)
			assert.matches("public interface MyInterface", content)
		end)

		it("generates enum content", function()
			local content = utils.generate_file_content("enum", "com.example", "MyEnum")
			assert.is_not_nil(content)
			assert.matches("public enum MyEnum", content)
		end)

		it("generates record content", function()
			local content = utils.generate_file_content("record", "com.example", "MyRecord")
			assert.is_not_nil(content)
			assert.matches("public record MyRecord", content)
		end)

		it("generates abstract class content", function()
			local content = utils.generate_file_content("abstract_class", "com.example", "MyAbstract")
			assert.is_not_nil(content)
			assert.matches("public abstract class MyAbstract", content)
		end)

		it("returns error for unknown type", function()
			local content, err = utils.generate_file_content("unknown", "com.example", "Foo")
			assert.is_nil(content)
			assert.matches("Template not found", err)
		end)

		it("includes default imports when configured", function()
			config.setup({
				default_imports = {
					class = { "java.util.List", "java.io.*" },
				},
			})
			local content = utils.generate_file_content("class", "com.example", "MyClass")
			assert.is_not_nil(content)
			assert.matches("import java%.util%.List;", content)
			assert.matches("import java%.io%.%*;", content)
		end)

		it("respects custom templates", function()
			config.setup({
				templates = {
					class = [[package %s;

// Custom header
public class %s {
    
}]],
				},
			})
			local content = utils.generate_file_content("class", "com.example", "MyClass")
			assert.is_not_nil(content)
			assert.matches("Custom header", content)
			assert.matches("public class MyClass", content)
		end)
	end)
end)
