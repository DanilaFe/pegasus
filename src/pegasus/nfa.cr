require "./automaton.cr"

module Pegasus
  module Nfa
    alias NState = Automata::State(Int64?, Transition)

    # A transition class used to represent the possible transitions
    # possible in the NFA.
    class Transition
    end

    # A transition that requires a single byte.
    class ByteTransition < Transition
      # The byte used for the transition.
      getter byte : UInt8

      # Creates a new byte transition.
      def initialize(@byte)
      end
    end

    # A transition that doesn't consume a token from the input.
    class LambdaTransition < Transition
    end

    # A transition that accepts any character.
    class AnyTransition < Transition
    end

    # A transition that accepts several ranges of bytes.
    class RangeTransition < Transition
      # The ranges this transition accepts / rejects.
      getter ranges : Array(Range(UInt8, UInt8))
      # If this is true, characters must __not__ be in the ranges to
      # be accepted.
      getter inverted : Bool

      # Creates a new range transition.
      def initialize(@ranges, @inverted)
      end
    end

    # A nondeterministic finite automaton, to be created
    # from regular expressions.
    class Nfa < Automata::Automaton(Int64?, Transition)
      # Creates a new Nfa with a start state.
      def initialize
        super
        @start = state_for(data: nil)
      end

      # Creates a new state for no value (aka, a set with nil as the value)
      def state
        state_for data: nil
      end
    end
  end
end
