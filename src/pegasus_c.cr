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
    end
  end
end

data = Pegasus::Language::LanguageData.from_json STDIN
data.output(STDOUT)
