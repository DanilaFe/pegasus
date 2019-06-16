require "../pegasus/language_def.cr"
require "../pegasus/json.cr"
require "../pegasus/semantics.cr"

require "option_parser"
require "ecr"

json_file_name = "prototype.json"
semantics_file_name = "prototype.sem"

json_string = File.read json_file_name
semantics_string = File.read semantics_file_name

language_data = Pegasus::Language::LanguageData.from_json json_string
semantics = Pegasus::Semantics::SemanticsData.new semantics_string, language_data

module Pegasus
end
