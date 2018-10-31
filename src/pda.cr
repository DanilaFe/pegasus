require "./elements.cr"
require "./automaton.cr"
require "./items.cr"

module Pegasus
  module Pda
    alias LRState = State(Set(LookaheadItem), Element)

    class LRPda < UniqueAutomaton(Set(LookaheadItem), Element)
    end

    alias LALRState = State(Set(DottedItem), Element)

    class LALRPda < UniqueAutomaton(Set(DottedItem), Element)
    end
  end
end
