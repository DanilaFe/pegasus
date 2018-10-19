module Pegasus
  module Nfa
    class Transition
      def char_states(alphabet)
        return {} of Char => Set(State)
      end
    end
    class CharTransition
      def char_states(alphabet)
        return { @char => Set{@other} }
      end
    end
    class AnyTransition
      def char_states(alphabet)
        return Hash.zip(alphabet, Array.new(alphabet.size, Set{@other}))
      end
    end
    class Nfa
      def find_lambda_states(s : State)
        found = Set(State).new
        queued = Set{s}
        while !queued.empty?
          state = queued.first
          queued.delete state
          next if found.includes? state

          found << state
          queued.concat state.transitions.select(&.is_a?(LambdaTransition)).map(&.other)
        end
        return found
      end

      def find_lambda_states(s : Set(State))
        return s
            .map { |it| find_lambda_states(it) }
            .reduce(Set(State).new) { |acc, s| acc.concat s }
      end

      private def merge_hashes(a : Array(Hash(K, Set(V)))) forall K, V
        a.reduce({} of K => Set(V)) { |l, r| l.merge(r) { |k, l1, r1| l1|r1 } }
      end

      private def get_state_for_set(nfa, hash, set)
        if hash.has_key? set
          return hash[set]
        else
          is_final = set.map(&.final).reduce { |l, r| l | r }
          state = nfa.state(final: is_final)
          hash[set] = state
          return state
        end
      end

      def almost_dfa(alphabet)
        raise "NFA doesn't have start state" unless @start

        # NFA (almost DFA) we're constructing
        new_nfa = Nfa.new
        # The NFA->DFA algorithm creates a state for every reachable combination of NFA states.
        # So, this is a set of "reachable states", and is itself a state.
        new_start_set = find_lambda_states(@start.not_nil!)
        # For every combination of states, the corresponding state in the new NFA.
        states = Hash(Set(State), State).new

        # The queue of states to process.
        queue = Set { new_start_set }
        # Visited states.
        finished = Set(Set(State)).new

        while !queue.empty?
          state_set = queue.first
          queue.delete state_set
          next if finished.includes? state_set

          finished << state_set
          current_state = get_state_for_set(new_nfa, states, state_set)

          out_transitions = merge_hashes(state_set.map { |s| merge_hashes(s.transitions.map(&.char_states alphabet)) })
          out_transitions.each do |char, ss|
            out_state_set = find_lambda_states(ss)
            out_state = get_state_for_set(new_nfa, states, out_state_set)
            current_state.transitions << CharTransition.new(char, out_state)
            queue << out_state_set
          end
        end

        new_nfa.start = states[new_start_set]

        return new_nfa
      end
    end
  end
end
