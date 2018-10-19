require "./nfa.cr"
require "./dot.cr"
require "./almost_nfa.cr"
require "./regex.cr"

# TODO: Write documentation for `Pegasus`
module Pegasus
  VERSION = "0.1.0"

  # TODO: Put your code here
end

nfa = Pegasus::Nfa::Nfa.new "hey+"
# puts nfa.to_dot
almost_dfa = nfa.almost_dfa (('a'..'z').to_a)
puts almost_dfa.to_dot
