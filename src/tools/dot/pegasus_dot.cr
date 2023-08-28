require "../../pegasus/language_def.cr"
require "../../pegasus/json.cr"
require "option_parser"

module Pegasus::Dot
  extend self

  # Outputs the DFA lexing state machine from the LanguageData.
  def output_dfa(data, io)
    io << "digraph G {\n"
    data.lex_state_table.each_with_index do |state, i|
      next if i == 0
      state_name = "q#{i}"

      state.each_with_index do |j, char|
        other_state_name = "q#{j}"
        if j != 0
          io << "  #{state_name} -> #{other_state_name} [label=#{char.chr.to_s.dump}]\n"
        end
      end
    end
    io << "}"
  end

  # Outputs the PDA parsing state machine from the LanguageData.
  def output_pda(data, io)
    io << "digraph G {\n"
    data.parse_state_table.each_with_index do |state, i|
      next if i == 0
      state_name = "q#{i}"

      state.each_with_index do |j, cause|
        other_state_name = "q#{j}"
        if j != 0
          if cause == 0
            transition_label = "(EOF)"
          elsif cause - 1 <= data.max_terminal
            transition_label = data.terminals.find { |k, v| v.raw_id == cause - 1 }.not_nil![0].dump
          else
            transition_label = data.nonterminals.find { |k, v| v.raw_id == cause - 1 - (data.max_terminal + 1) }.not_nil![0].dump
          end
          io << "  #{state_name} -> #{other_state_name} [label=#{transition_label}]\n"
        end
      end
    end
    io << "}"
  end

  # Output target specified on command line.
  enum OutputTarget
    # Print DOT for DFA
    Dfa
    # Print DOT for PDA
    Pda
  end
end

# Configuration options
output_target = Pegasus::Dot::OutputTarget::Pda

# Parse configuration from command line
OptionParser.parse do |parser|
  parser.banner = "Usage: pegasus-dot [arguments]"
  parser.on("-o FORMAT", "--output FORMAT",
            "Specifies the output format of the DOT converter. Either \"Dfa\" or \"Pda\"") do |format|
    output_target = Pegasus::Dot::OutputTarget.parse? format
    if output_target == nil
      STDERR.puts "ERROR: #{format} is not a valid format option."
      STDERR.puts parser
      exit(1)
    end
  end
  parser.on("-h", "--help", "Show this help") { puts parser }
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

# Reaad, parse, and output LanguageData.
data = Pegasus::Language::LanguageData.from_json STDIN
case output_target
when Pegasus::Dot::OutputTarget::Dfa
  Pegasus::Dot.output_dfa(data, STDOUT)
when Pegasus::Dot::OutputTarget::Pda
  Pegasus::Dot.output_pda(data, STDOUT)
end
