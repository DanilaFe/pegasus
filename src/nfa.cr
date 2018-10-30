require "./automaton.cr"

module Pegasus
  module Nfa
    alias NState = State(Int64?, Array(Transition))

    class Transition
      property other : NState

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

    class Nfa < Automaton(Int64?, Array(Transition))
      def initialize
        super
        @start = state_for(data: nil)
      end

      def state
        state_for data: nil
      end
    end
  end
end
