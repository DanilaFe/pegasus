require "./automaton.cr"

module Pegasus
  module Nfa
    alias NState = State(Int64?, Transition)

    class Transition
    end

    class ByteTransition < Transition
      getter byte : UInt8

      def initialize(@byte)
      end
    end

    class LambdaTransition < Transition
    end

    class AnyTransition < Transition
    end

    class RangeTransition < Transition
      getter ranges : Array(Range(UInt8, UInt8))
      getter inverted : Bool

      def initialize(@ranges, @inverted)
      end
    end

    class Nfa < Automaton(Int64?, Transition)
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
