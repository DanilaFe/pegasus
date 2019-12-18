require "../../pegasus/language_def.cr"
require "ecr"

module Pegasus::Generators
  class CrystalTableGen
    def initialize(@prefix : String, @language : Pegasus::Language::LanguageData)
    end

    ECR.def_to_s "src/generators/crystal-common/tables.ecr"
  end
end
