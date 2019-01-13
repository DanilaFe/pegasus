require "../pegasus/language_def.cr"
require "../pegasus/json.cr"
require "option_parser"

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
          transition_label = data.terminals.key_for(Pegasus::Elements::TerminalId.new((cause - 1).to_i64)).dump
        else
          transition_label = data.nonterminals.key_for(Pegasus::Elements::NonterminalId.new((cause - 2 - data.max_terminal).to_i64)).dump
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
  Dfa,
  # Print DOT for PDA
  Pda
end

# Configuration options
output_target = OutputTarget::Pda

# Parse configuration from command line
OptionParser.parse! do |parser|
  parser.banner = "Usage: pegasus-dot [arguments]"
  parser.on("-o FORMAT", "--output FORMAT",
            "Specifies the output format of the DOT converter. Either \"Dfa\" or \"Pda\"") do |format|
    output_target = OutputTarget.parse? format
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
when OutputTarget::Dfa
  output_dfa(data, STDOUT)
when OutputTarget::Pda
  output_pda(data, STDOUT)
end
