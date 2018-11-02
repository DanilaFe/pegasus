require "./nfa.cr"
require "./pda.cr"

class Object
  def dot_label
    to_s
  end
end

struct UInt8
  def dot_label
    "#{chr}"
  end
end

module Pegasus
  class State(V, T)
    def dot_label
      "q#{@id}"
    end
  end

  class Automaton(V, T)
    def to_dot
      memory = IO::Memory.new
      memory << "digraph G {\n"
      if start_state = @start
        memory << "  "
        memory << start_state.dot_label
        memory << " [shape=diamond]\n"
      end
      @states.each do |state|
        label = state.dot_label
        if state.data
          memory << "  "
          memory << label
          memory << " [shape=doublecircle]\n"
        end
        state.transitions.each do |t, s|
          other_label = s.dot_label
          t_label = t.dot_label

          memory << "  "
          memory << label
          memory << " -> "
          memory << other_label
          memory << " [ label=\""
          memory << t_label
          memory << "\" ] \n"
        end
      end
      memory << "}"
      return memory.to_s
    end
  end

  module Nfa
    class Transition
      def dot_label
        ""
      end
    end

    class ByteTransition
      def dot_label
        "#{@byte.chr}"
      end
    end

    class LambdaTransition
      def dot_label
        "(lambda)"
      end
    end
  end
end
