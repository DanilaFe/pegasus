require "../../pegasus/language_def.cr"
require "ecr"

module Pegasus::Generators
  class CTableGen
    def initialize(@language : Pegasus::Language::LanguageData)
    end

    ECR.def_to_s "src/generators/c-common/tables.ecr"
  end
end
