require "./automaton.cr"
require "./nfa.cr"

module Pegasus
  module Dfa
    alias DState = State(Set(Nfa::NState), UInt8)

    class Dfa < UniqueAutomaton(Set(Nfa::NState), UInt8)
    end
  end
end
