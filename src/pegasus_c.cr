require "./language_def.cr"
require "./json.cr"
require "option_parser"
require "ecr"

module Pegasus
  module Language
    class LanguageData
      def output(io)
        ECR.embed "src/pegasus_c_template.ecr", io
      end

      def to_file(name)
        file = File.open name, mode: "w"
        ECR.embed "src/pegasus_c_header_template.ecr", file
        file << "\n"
        ECR.embed "src/pegasus_c_template.ecr", file
        file.close
      end

      def to_files(*, header_file, source_file,
                   header_prefix = "")
        header_file_io = File.open header_file, mode: "w"
        source_file_io = File.open source_file, mode: "w"

        ECR.embed "src/pegasus_c_header_template.ecr", header_file_io

        source_file_io << "#include \"#{header_prefix + header_file}\""
        source_file_io.puts
        ECR.embed "src/pegasus_c_template.ecr", source_file_io

        header_file_io.close
        source_file_io.close
      end
    end
  end
end

data = Pegasus::Language::LanguageData.from_json STDIN
data.to_file("test.c")
data.to_files(header_file: "new_test.h", source_file: "new_test.c")
