require "../pegasus/language_def.cr"
require "../pegasus/json.cr"
require "../pegasus/semantics.cr"

require "option_parser"
require "ecr"

struct SemanticPrinter
  def initialize(@language : Pegasus::Language::LanguageData, @semantics : Pegasus::Semantics::SemanticsData)
    
  end

  def output(io)
    ECR.embed "src/csem/pegasus_c_template.ecr", io
  end

  def to_io(io)
    ECR.embed "src/csem/pegasus_c_header_template.ecr", io
    io << "\n"
    ECR.embed "src/csem/pegasus_c_template.ecr", io
  end

  def to_file(name)
    file = File.open name, mode: "w"
    to_io file
    file.close
  end

  def format_item(index, code)
    item = @language.items[index]
    
    raise_general "no type specified for nonterminal" unless head_type = @semantics.nonterminal_types[item.head]?
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

  def to_files(*, header_file, impl_file)
    header_file_io = File.open header_file, mode: "w"
    impl_file_io = File.open impl_file, mode: "w"

    ECR.embed "src/csem/pegasus_c_header_template.ecr", header_file_io

    impl_file_io << "#include \"" << header_file << "\""
    impl_file_io.puts
    ECR.embed "src/csem/pegasus_c_template.ecr", impl_file_io

    header_file_io.close
    impl_file_io.close
  end
end

grammar_name = ""
semantics_name = ""
file_prefix = ""
file_name = "parser"
header_name = nil
impl_name = nil
split = true
stdout = false

OptionParser.parse! do |parser|
  parser.banner = "Usage: pegasus-csem [arguments]"
  parser.on("-a", "--grammar=GRAMMAR", "Set the grammar JSON file source") { |name| grammar_name = name }
  parser.on("-b", "--semantics=SEMANTICS", "Set the semantics file source") { |name| semantics_name = name }
  parser.on("-s", "--single-file", "Combines the header and implementation files into one") { split = false }
  parser.on("-S", "--standard-out", "Combines the header and implementation files, and prints to standard out") { split = false; stdout = true }
  parser.on("-p PREFIX", "--prefix=PREFIX", "Sets prefix for generate files") { |prefix| file_prefix = prefix }
  parser.on("-f FILE", "--file-name=", "Sets output file name") { |file| file_name = file }
  parser.on("-H HEADER", "--header-name=HEADER", "Sets the header file name. Ignores prefix") { |header| header_name = header }
  parser.on("-i IMPL", "--implementation-name=IMPL", "Sets the implementation file name. Ignores prefix") { |impl| impl_name = impl }
  parser.on("-h", "--help", "Displays this message") { puts parser }
end

begin
  grammar = Pegasus::Language::LanguageData.from_json File.read(grammar_name)
  semantics = Pegasus::Semantics::SemanticsData.new File.read(semantics_name), grammar
  printer = SemanticPrinter.new(grammar, semantics)

  if split
    printer.to_files(header_file: (header_name || (file_prefix + file_name + ".h")).not_nil!,
                  impl_file: (impl_name || (file_prefix + file_name + ".c")).not_nil!)
  elsif stdout
    printer.to_io(STDOUT)
  else
    printer.to_file(file_prefix + file_name + ".c")
  end
rescue e : Pegasus::Error::PegasusException
  e.print(STDOUT)
end
