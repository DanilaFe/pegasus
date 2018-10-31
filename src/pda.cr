require "./elements.cr"
require "./automaton.cr"
require "./items.cr"

module Pegasus
  module Pda
    alias PState = State(Set(LookaheadItem), Element)

    class Pda < UniqueAutomaton(Set(LookaheadItem), Element)
      def initialize(@items : Set(Item))
        super()
      end
    end
  end
end
