require "../../pegasus/language_def.cr"
require "../../pegasus/json.cr"
require "option_parser"
require "ecr"

module Pegasus
  module Language
    class LanguageData
      def output(io)
        ECR.embed "src/generators/c/pegasus_c_template.ecr", io
      end

      def to_io(io)
        ECR.embed "src/generators/c/pegasus_c_header_template.ecr", io
        io << "\n"
        ECR.embed "src/generators/c/pegasus_c_template.ecr", io
      end

      def to_file(name)
        file = File.open name, mode: "w"
        to_io file
        file.close
      end

      def to_files(*, header_file, impl_file)
        header_file_io = File.open header_file, mode: "w"
        impl_file_io = File.open impl_file, mode: "w"

        ECR.embed "src/generators/c/pegasus_c_header_template.ecr", header_file_io

        impl_file_io << "#include \"" << header_file << "\""
        impl_file_io.puts
        ECR.embed "src/generators/c/pegasus_c_template.ecr", impl_file_io

        header_file_io.close
        impl_file_io.close
      end
    end
  end
end

file_prefix = ""
file_name = "parser"
header_name = nil
impl_name = nil
split = true
stdout = false

OptionParser.parse! do |parser|
  parser.banner = "Usage: pegasus-c [arguments]"
  parser.on("-s", "--single-file", "Combines the header and implementation files into one") { split = false }
  parser.on("-S", "--standard-out", "Combines the header and implementation files, and prints to standard out") { split = false; stdout = true }
  parser.on("-p PREFIX", "--prefix=PREFIX", "Sets prefix for generate files") { |prefix| file_prefix = prefix }
  parser.on("-f FILE", "--file-name=", "Sets output file name") { |file| file_name = file }
  parser.on("-H HEADER", "--header-name=HEADER", "Sets the header file name. Ignores prefix") { |header| header_name = header }
  parser.on("-i IMPL", "--implementation-name=IMPL", "Sets the implementation file name. Ignores prefix") { |impl| impl_name = impl }
  parser.on("-h", "--help", "Displays this message") { puts parser }
end

data = Pegasus::Language::LanguageData.from_json STDIN
if split
  data.to_files(header_file: (header_name || (file_prefix + file_name + ".h")).not_nil!,
                impl_file: (impl_name || (file_prefix + file_name + ".c")).not_nil!)
elsif stdout
  data.to_io(STDOUT)
else
  data.to_file(file_prefix + file_name + ".c")
end
