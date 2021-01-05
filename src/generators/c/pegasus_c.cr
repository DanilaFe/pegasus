require "../../pegasus/language_def.cr"
require "../../pegasus/json.cr"
require "../c-common/tables.cr"
require "../generators.cr"
require "option_parser"
require "ecr"

module Pegasus::Generators::C
  include Pegasus::Language
  include Pegasus::Generators::Api

  class CContext
    def add_option(opt_parser)
    end
  end

  class LanguageInput < StdInput(LanguageData)
    def process(opt_parser) : LanguageData
      LanguageData.from_json STDIN
    end
  end

  class HeaderGenerator < FileGenerator(CContext, LanguageData)
    def initialize(parent)
      super parent, "header", "parser.h", "the parser header file"
    end

    def to_s(io)
      ECR.embed "src/generators/c/pegasus_c_header_template.ecr", io 
    end
  end

  class SourceGenerator < FileGenerator(CContext, LanguageData)
    def initialize(parent)
      super parent, "code", "parser.c", "the parser source code file"
    end

    def to_s(io)
      io << "#include \"#{@parent.output_file_names["header"]}\"\n"
      ECR.embed "src/generators/c/pegasus_c_template.ecr", io 
    end
  end
end

include Pegasus::Generators::C

parser = PegasusOptionParser(CContext, LanguageData).new LanguageInput.new
HeaderGenerator.new(parser)
SourceGenerator.new(parser)
parser.run
