require "./elements.cr"
require "./automaton.cr"
require "./items.cr"

module Pegasus
  module Pda
    alias LRState = State(Set(LookaheadItem), Hash(Element, LRState))

    class LRPda < UniqueAutomaton(Set(LookaheadItem), Hash(Element, LRState))
    end

    alias LALRState = State(Set(DottedItem), Hash(Element, LALRState))

    class LALRPda < UniqueAutomaton(Set(DottedItem), Hash(Element, LALRState))
    end
  end
end
