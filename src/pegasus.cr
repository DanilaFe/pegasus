require "./pegasus/language_def.cr"
require "./pegasus/json.cr"
require "./pegasus/error.cr"

begin
  grammar = STDIN.gets_to_end
  definition = Pegasus::Language::LanguageDefinition.new grammar
  data = Pegasus::Language::LanguageData.new definition
  data.to_json(STDOUT)
rescue e : Pegasus::Error::PegasusException
  e.print(STDERR)
end
