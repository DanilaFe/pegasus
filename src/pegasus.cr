require "./language_def.cr"
require "./json.cr"
require "./error.cr"

begin
  grammar = STDIN.gets_to_end
  data = Pegasus::Language::LanguageDefinition.new(grammar).generate
  data.to_json(STDOUT)
rescue e : Pegasus::Error::PegasusError
  e.to_s(STDERR)
end

