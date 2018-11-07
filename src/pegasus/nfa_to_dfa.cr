require "./nfa.cr"
require "./dfa.cr"
require "./error.cr"

module Pegasus
  module Nfa
    class Transition
      # Returns the characters this transition accepts
      # for transitions.
      def char_states
        return [] of UInt8
      end
    end

    class ByteTransition
      def char_states
        return [ @byte ]
      end
    end

    class AnyTransition
      def char_states
        return (0_u8..255_u8).to_a
      end
    end

    class RangeTransition
      def char_states
        states = @ranges.map(&.to_a).flatten
        states = (0_u8..255_u8).to_a - states if @inverted
        return states
      end
    end

    class Nfa
      # Finds all the states connected to the given state
      # through lambda transitions, which will be in the same `Pegasus::Dfa::Dfa` state.
      private def find_lambda_states(s : NState)
        found = Set(NState).new
        queued = Set{s}
        while !queued.empty?
          state = queued.first
          queued.delete state
          next if found.includes? state

          found << state
          queued.concat state.transitions.select(&.is_a?(LambdaTransition)).map(&.[1])
        end
        return found
      end

      # Finds the lambda states connected to any of the states of the given set.
      def find_lambda_states(s : Set(NState))
        return s
            .map { |it| find_lambda_states(it) }
            .reduce(Set(NState).new) { |acc, r| acc.concat r }
      end

      # Merges the sets mapped to by the same key in the list of hashes.
      private def merge_hashes(a : Array(Hash(K, Set(V)))) forall K, V
        a.reduce({} of K => Set(V)) { |l, r| l.merge(r) { |_, l1, r1| l1|r1 } }
      end

      # Creates a `Pegasus::Dfa::Dfa` for this Nfa.
      def dfa
        raise_dfa "NFA doesn't have start state" unless @start

        # DFA we're constructing
        new_dfa = Pegasus::Dfa::Dfa.new
        # The NFA->DFA algorithm creates a state for every reachable combination of NFA states.
        # So, this is a set of "reachable states", and is itself a state.
        new_start_set = find_lambda_states(@start.not_nil!)
        new_start = new_dfa.state_for data: new_start_set

        # The queue of states to process.
        queue = Set { new_start }
        # Visited states.
        finished = Set(Pegasus::Dfa::DState).new

        while !queue.empty?
          state = queue.first
          queue.delete state
          next if finished.includes? state

          finished << state
          sub_hashes = state.data.map do |sub_state|
              transition_hashes = sub_state.transitions.map do |k, v|
                char_states = k.char_states
                set_array = Array.new(char_states.size) do
                  Set { v }
                end
                Hash.zip(char_states, set_array)
              end
              merge_hashes(transition_hashes)
          end
          out_transitions = merge_hashes(sub_hashes)
          out_transitions.each do |char, ss|
            out_state_set = find_lambda_states(ss)
            out_state = new_dfa.state_for data: out_state_set
            state.transitions[char] = out_state
            queue << out_state
          end
        end

        return new_dfa
      end
    end
  end
end
