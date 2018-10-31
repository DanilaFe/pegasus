module Pegasus
  class State(V, T)
    getter id : Int64
    getter data : V
    getter transitions : Hash(T, self)

    def initialize(*, @id, @data, @transitions = Hash(T, self).new)
    end
  end

  class Automaton(V, T)
    getter states : Set(State(V, T))
    getter last_id : Int64
    property start : State(V, T)?

    def initialize
      @last_id = 0_i64
      @states = Set(State(V, T)).new
      @start = nil
    end

    def state_for(*, data : V)
      new_state = State(V, T).new id: @last_id, data: data
      @last_id += 1
      @states << new_state
      return new_state
    end
  end

  class UniqueAutomaton(V, T) < Automaton(V, T)
    def initialize
      super
      @memorized = Hash(V, State(V, T)).new
    end

    def state_for(*, data : V)
      return @memorized[data] if @memorized.has_key? data
      new_state = super(data: data)
      @memorized[data] = new_state
      return new_state
    end
  end
end
