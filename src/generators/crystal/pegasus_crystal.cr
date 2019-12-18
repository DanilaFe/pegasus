require "../../pegasus/language_def.cr"
require "../../pegasus/json.cr"
require "../crystal-common/tables.cr"
require "option_parser"
require "ecr"

module Pegasus
  module Language
    class LanguageData
      def output(io, prefix)
        ECR.embed "src/generators/crystal/pegasus_crystal_template.ecr", io
      end
    end
  end
end

prefix = "Pegasus::Generated"
file_name = "parser"
stdout = false

OptionParser.parse! do |parser|
  parser.banner = "Usage: pegasus-crystal [arguments]"
  parser.on("-S", "--standard-out", "Combines the header and implementation files, and prints to standard out") { stdout = true }
  parser.on("-P PREFIX", "--prefix PREFIX", "Specify the prefix for generated code") do |p|
    prefix = p
  end
  parser.on("-f FILE", "--file-name=FILE", "Sets output file name") { |file| file_name = file }
  parser.on("-h", "--help", "Displays this message") { puts parser }
end

data = Pegasus::Language::LanguageData.from_json STDIN
if stdout
  data.output STDOUT, prefix
else
  file = File.open(file_name + ".cr", mode: "w")
  data.output file, prefix
  file.close
end
