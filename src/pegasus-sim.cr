require "./language_def.cr"
require "./json.cr"
require "option_parser"

class Token
  getter id : Int64
  getter string : String

  def initialize(@id, @string)
  end

  def to_s(io)
    io << "Token(" << id << ", " << string << ")"
  end
end

abstract class Tree
  abstract def table_index : Int64

  def display(io, offset)
  end
end

class TokenTree < Tree
  def initialize(@token : Token)
  end

  def table_index
    @token.id
  end
  
  def display(io, offset)
    offset.times { io << "  " }
    io << @token
    io.puts
  end
end

class ParentTree < Tree
  getter children : Array(Tree)

  def initialize(@nonterminal_id : Int64, @max_terminal : Int64, @children = [] of Tree, @name : String? = nil)
  end

  def table_index
    @max_terminal + 1 + 1 + @nonterminal_id
  end

  def display(io, offset)
    offset.times { io << "  " }
    io << "ParentTree(" << (@name || @nonterminal_id) << ")"
    io.puts
    @children.each { |child| child.display(io, offset + 1) }
  end
end

input_json_option = nil

OptionParser.parse! do |parser|
  parser.banner = "Usage: pegasus-sim [arguments]"
  parser.on("-i FILE", "--input FORMAT", "Specifies input JSON file") do |file|
    input_json_option = file
  end
  parser.on("-h", "--help", "Show this help") { puts parser }
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

raise "Input file not specified" unless input_json_option
input_json = input_json_option.not_nil!

raise "Unable to open specified file" unless File.file? input_json
input = File.read input_json

data = Pegasus::Language::LanguageData.from_json input
to_parse = STDIN.gets_to_end.chomp

# Lexing code

tokens = [] of Token
# Index at the string
index = 0_i64
# The last "final" match.
last_final = -1_i64
# The location of the last "final" match.
last_final_index = -1_i64
# The beginning of the last token.
last_start = 0_i64
# The current state
state = 1_i64

while index < to_parse.size
  last_final = -1_i64
  last_final_index = -1_i64
  last_start = index
  state = 1_i64

  while (index < to_parse.size) && (state != 0_i64)
    state = data.lex_state_table[state][to_parse[index].bytes[0]]
    if (final = data.lex_final_table[state]) != 0
      last_final = final
      last_final_index = index
      index += 1
    end
  end

  break if last_final == -1
  tokens << Token.new last_final, to_parse[last_start..last_final_index]
end

raise "Invalid token at position #{index}" unless index == to_parse.size

# Parsing code

# Technically this is one stack. However, it's easier to keep track
# of the two types of variables on the stack separately.

# The stack of trees being assembled from the bottom up.
tree_stack = [] of Tree
# The stack of the states to be followed by the automaton.
state_stack = [ 1_i64 ]
# The index in the tokens
index = 0_i64
# Final state table ID
final_id = data.max_terminal + 1 + 1

while true
  break if (top = tree_stack.last?) && top.table_index == final_id
  action = data.parse_action_table[state_stack.last][(tokens[index]?.try &.id) || 0_i64]

  raise "Invalid token at position #{index}" if action == -1_i64
  if action == 0
    raise "Unexpected end of file" unless index < tokens.size
    tree_stack << TokenTree.new tokens[index]
    index += 1
  else
    item = data.items[action - 1]
    new_children = [] of Tree

    item.body.size.times do
      new_children.insert 0, tree_stack.pop 
      state_stack.pop
    end
    tree_stack << ParentTree.new item.head.id, data.max_terminal,
      new_children,
      data.nonterminals.key_for(Pegasus::Pda::Nonterminal.new item.head.id)
  end
  state_stack << data.parse_state_table[state_stack.last][tree_stack.last.table_index]
end
tree_stack.last.display(STDOUT, 0)
