module Pegasus
  module Nfa
    class Transition
      property other : State

      def initialize(@other)
      end
    end

    class ByteTransition < Transition
      getter byte : UInt8

      def initialize(@byte, @other)
      end
    end

    class LambdaTransition < Transition
      def initialize(@other)
      end
    end

    class AnyTransition < Transition
      def initialize(@other)
      end
    end

    class RangeTransition < Transition
      getter ranges : Array(Range(UInt8, UInt8))
      getter inverted : Bool

      def initialize(@ranges, @inverted, @other)
      end
    end

    class State
      property final_id : Int64?
      property id : Int64
      property transitions : Array(Transition)
      
      def initialize(*, @id = -1, @final_id = nil, @transitions = [] of Transition)
      end
    end

    class Nfa
      getter states : Set(State)
      property start : State

      def initialize(start = nil)
        @last_id = 0_i64
        @states = Set(State).new
        @start = start || state
      end

      def state(*, final_id : Int64? = nil)
        new_state = State.new(id: @last_id, final_id: final_id);
        @last_id += 1
        @states << new_state
        return new_state
      end
    end
  end
end
