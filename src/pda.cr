require "./elements.cr"
require "./automaton.cr"
require "./items.cr"

module Pegasus
  module Pda
    alias PState = State(Set(DottedItem), Hash(Element, PState))

    class Pda < UniqueAutomaton(Set(DottedItem), Hash(Element, PState))
    end
  end
end
