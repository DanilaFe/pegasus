require "./elements.cr"
require "./items.cr"

module Pegasus
  module Pda
    class State
      property id : Int64
      property items : Set(DottedItem)
      property transitions : Hash(Element, State)

      def initialize(*, @id = -1_i64, @items, @transitions = {} of Element => State)
      end
    end

    class Pda
      getter states : Set(State)
      property start : State?

      def initialize(@start = nil)
        @last_id = 0_i64
        @states = Set(State).new
      end

      def state(items)
        new_state = State.new(id: @last_id, items: items)
        @last_id += 1
        @states << new_state
        return new_state
      end
    end
  end
end
