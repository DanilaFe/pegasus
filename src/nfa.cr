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
      property final : Bool
      property id : Int64
      property transitions : Array(Transition)
      
      def initialize(*, @id : Int64 = -1, @final : Bool = false, @transitions = [] of Transition)
      end
    end

    class Nfa
      getter states : Set(State)
      property start : State?

      def initialize
        @last_id = 0_i64
        @states = Set(State).new
        @start = nil
      end

      def state(*, final : Bool)
        new_state = State.new(id: @last_id, final: final);
        @last_id += 1
        @states << new_state
        return new_state
      end
    end
  end
end
