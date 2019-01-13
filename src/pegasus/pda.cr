require "./elements.cr"
require "./automaton.cr"
require "./items.cr"

module Pegasus
  module Pda
    alias PState = Automata::State(Set(LookaheadItem), Elements::NonterminalId | Elements::TerminalId)

    # A class that represents the (LA)LR Push Down Automaton.
    class Pda < Automata::UniqueAutomaton(Set(LookaheadItem), Elements::NonterminalId | Elements::TerminalId)
      def initialize(@items : Array(Item))
        super()
      end
    end
  end
end
