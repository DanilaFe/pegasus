require "./elements.cr"
require "./automaton.cr"
require "./items.cr"

module Pegasus
  module Pda
    alias PState = State(Set(LookaheadItem), NonterminalId | TerminalId)

    # A class that represents the (LA)LR Push Down Automaton.
    class Pda < UniqueAutomaton(Set(LookaheadItem), NonterminalId | TerminalId)
      def initialize(@items : Array(Item))
        super()
      end
    end
  end
end
