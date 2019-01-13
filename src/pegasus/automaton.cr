module Pegasus
  # This module contains automata-related code. Since Pegasus uses
  # Deterministic, nondeterministic, and push-down automata, there is a lot
  # of common code. This module is for the common code.
  module Automata
    # A generic state for an automaton, with transitions
    # labeled by T and values of V.
    class State(V, T)
      # The unique ID of the state.
      getter id : Int64
      # The additional data the state holds.
      getter data : V
      # The transitions from this state to other states.
      getter transitions : Hash(T, self)

      # Creates a new state with the given ID, data, and transitions.
      def initialize(*, @id, @data, @transitions = Hash(T, self).new)
      end
    end

    # A generic automaton to represent common operations on the
    # different kinds of automata.
    class Automaton(V, T)
      # The states that this automaton has.
      getter states : Set(State(V, T))
      # The state ID to use for the next state.
      getter last_id : Int64
      # The start state.
      property start : State(V, T)?

        # Creates a new automaton.
        def initialize
          @last_id = 0_i64
          @states = Set(State(V, T)).new
          @start = nil
      end

      # Creates a new state for the given data.
      def state_for(*, data : V)
        new_state = State(V, T).new id: @last_id, data: data
        @last_id += 1
        @states << new_state
        return new_state
      end
    end

    # Another generic automaton. Since many automatons created by
    # pegasus do not like two nodes with the same data,
    # this class overries the `#state_for` function to return
    # an existing state with the given data if such a state exists.
    class UniqueAutomaton(V, T) < Automaton(V, T)
      # Creates a new UniqueAutomaton.
      def initialize
        super
        @memorized = Hash(V, State(V, T)).new
      end

      # Creates a new state for the given data,
      # or returns an existing state with the data
      # if one exists.
      def state_for(*, data : V)
        return @memorized[data] if @memorized.has_key? data
        new_state = super(data: data)
        @memorized[data] = new_state
        return new_state
      end
    end
  end
end
