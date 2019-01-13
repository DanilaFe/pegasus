require "./automaton.cr"
require "./nfa.cr"

module Pegasus
  module Dfa
    alias DState = Automata::State(Set(Nfa::NState), UInt8)

    # A deterministic finite automaton, whose dtransitions
    # are marked by bytes and whose data is actually the collection
    # of states this state represents in the source `Pegasus::Nfa::Nfa`.
    class Dfa < Automata::UniqueAutomaton(Set(Nfa::NState), UInt8)
    end
  end
end
