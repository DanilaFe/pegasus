require "./automaton.cr"
require "./nfa.cr"

module Pegasus
  module Dfa
    alias DState = State(Set(Nfa::NState), Hash(UInt8, DState))

    class Dfa < UniqueAutomaton(Set(Nfa::NState), Hash(UInt8, DState))
    end
  end
end
