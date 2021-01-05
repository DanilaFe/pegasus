require "../../pegasus/language_def.cr"
require "../../pegasus/json.cr"
require "../../pegasus/semantics.cr"
require "../c-common/tables.cr"
require "../generators.cr"
require "option_parser"
require "ecr"

module Pegasus::Generators::CSem
  include Pegasus::Language
  include Pegasus::Generators::Api
  include Pegasus::Semantics

  class CContext
    def add_option(opt_parser)
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
      code = code.gsub "$out", "temp." + head_type

      item.body.each_with_index do |element, i|
        data_var = "stack.data[stack.size - 1 - #{item.body.size - 1 - i}].value"
        case element
        when Pegasus::Elements::TerminalId
          data_var += ".token"
          code = code.gsub "$#{i}", "(" + data_var + ")"
        when Pegasus::Elements::NonterminalId
          next unless name = @semantics.nonterminal_types[element]
          data_var += "." + name
          code = code.gsub "$#{i}", "(" + data_var + ")"
        end
      end

      return "{ { #{code} } break; }"
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
      semantics_data = SemanticsData.new file.gets_to_end, "pgs_token*", language_data
      GeneratorInput.new(language_data,semantics_data)
    end

    def add_option(opt_parser)
      @language_input.add_option(opt_parser)
      super opt_parser
    end
  end

  class HeaderGenerator < FileGenerator(CContext, GeneratorInput)
    def initialize(parent)
      super parent, "header", "parser.h", "the parser header file"
    end

    def to_s(io)
      ECR.embed "src/generators/csem/pegasus_c_header_template.ecr", io 
    end
  end

  class SourceGenerator < FileGenerator(CContext, GeneratorInput)
    def initialize(parent)
      super parent, "code", "parser.c", "the parser source code file"
    end

    def to_s(io)
      io << "#include \"#{@parent.output_file_names["header"]}\"\n"
      ECR.embed "src/generators/csem/pegasus_c_template.ecr", io 
    end
  end
end

include Pegasus::Generators::CSem

parser = PegasusOptionParser(CContext, GeneratorInput).new FullInput.new(LanguageInput.new)
HeaderGenerator.new(parser)
SourceGenerator.new(parser)
parser.run
