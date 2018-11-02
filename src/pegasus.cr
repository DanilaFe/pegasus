require "./language_def.cr"
require "./json.cr"

# TODO: Write documentation for `Pegasus`
module Pegasus
  VERSION = "0.1.0"

  # TODO: Put your code here
end

grammar = STDIN.gets_to_end

data = Pegasus::Language::LanguageDefinition
  .new(grammar)
  .generate
data.to_json(STDOUT)
