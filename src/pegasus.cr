require "./language_def.cr"
require "./json.cr"
require "./error.cr"

begin
  grammar = STDIN.gets_to_end
  definition = Pegasus::Language::LanguageDefinition.new grammar
  data = Pegasus::Language::LanguageData.new definition
  data.to_json(STDOUT)
rescue e : Pegasus::Error::PegasusError
  e.to_s(STDERR)
end

