require "../../pegasus/language_def.cr"
require "../../pegasus/json.cr"
require "../../pegasus/semantics.cr"
require "../crystal-common/tables.cr"
require "../generators.cr"
require "option_parser"
require "ecr"

module Pegasus::Generators::CrystalSem
  include Pegasus::Language
  include Pegasus::Generators::Api
  include Pegasus::Semantics

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

  class GeneratorInput
    property language : LanguageData
    property semantics : SemanticsData

    def initialize(@language, @semantics)
    end

    def format_item(index, code)
      item = @language.items[index]

      unless head_type = @semantics.nonterminal_types[item.head]?
          raise_general "no type specified for nonterminal" 
      end
      code = code.gsub "$out", "temp"

      item.body.each_with_index do |element, i|
        data_var = "value_stack[-1-#{item.body.size - 1 - i}]"
        case element
        when Pegasus::Elements::TerminalId
          data_var += ".as(Token)"
          code = code.gsub "$#{i}", "(" + data_var + ")"
        when Pegasus::Elements::NonterminalId
          next unless name = @semantics.nonterminal_types[element]
          data_var += ".as(#{@semantics.types[name]})"
          code = code.gsub "$#{i}", "(" + data_var + ")"
        end
      end

      return code
    end
  end

  class LanguageInput < FileInput(LanguageData)
    def initialize
      super "language", "the grammar file"
    end

    def process(opt_parser, file) : LanguageData
      LanguageData.from_json file
    end
  end

  class FullInput < FileInput(GeneratorInput)
    def initialize(@language_input : Input(LanguageData))
      super "actions", "the semantic actions file"
    end

    def process(opt_parser, file) : GeneratorInput
      language_data = @language_input.process(opt_parser)
      semantics_data = SemanticsData.new file.gets_to_end, "Token", language_data
      GeneratorInput.new(language_data,semantics_data)
    end

    def add_option(opt_parser)
      @language_input.add_option(opt_parser)
      super opt_parser
    end
  end

  class SourceGenerator < FileGenerator(CrystalContext, GeneratorInput)
    def initialize(parent)
      super parent, "code", "parser.cr", "the parser source code file"
    end

    def to_s(io)
      ECR.embed "src/generators/crystalsem/pegasus_crystal_template.ecr", io 
    end
  end
end

include Pegasus::Generators::CrystalSem

parser = PegasusOptionParser(CrystalContext, GeneratorInput).new FullInput.new(LanguageInput.new)
SourceGenerator.new(parser)
parser.run
