require "../../pegasus/language_def.cr"
require "../../pegasus/json.cr"
require "../crystal-common/tables.cr"
require "../generators.cr"
require "option_parser"
require "ecr"

module Pegasus::Generators::Crystal
  include Pegasus::Language
  include Pegasus::Generators::Api

  class CrystalContext
    property output_module : String

    def initialize(@output_module : String = "Pegasus::Generated")
    end

    def add_option(opt_parser)
      opt_parser.option_parser.on("-m",
                                  "--module=MODULE",
                                  "Sets the module in generated code") do |m|
                                    @output_module = m
                                  end
    end
  end

  class LanguageInput < StdInput(LanguageData)
    def process(opt_parser) : LanguageData
      LanguageData.from_json STDIN
    end
  end

  class ParserGenerator < FileGenerator(CrystalContext, LanguageData)
    def initialize(parent)
      super parent, "parser", "parser.cr", "the generated parser file"
    end

    def to_s(io)
      ECR.embed "src/generators/crystal/pegasus_crystal_template.ecr", io 
    end
  end
end

include Pegasus::Generators::Crystal

parser = PegasusOptionParser(CrystalContext, LanguageData).new LanguageInput.new
ParserGenerator.new(parser)
parser.run
