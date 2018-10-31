module Pegasus
  module Nfa
    class StateChain
      property start : NState
      property final : NState

      def initialize(@start, @final = @start)
      end

      def append!(other : StateChain)
        if @final == nil
          @start = other.start
          @final = other.final
        elsif other.start
          @final.not_nil!.transitions[LambdaTransition.new] = other.start.not_nil!
          @final = other.final
        end
        return self
      end
      
      def append!(other : Nil)
        return self
      end
    end

    class Nfa
      private def nfa_plus(chain)
        if chain.start && chain.final
          new_final = state
          new_start = state
          new_final.transitions[LambdaTransition.new] = new_start
          chain.final.transitions[LambdaTransition.new] = new_final
          new_start.transitions[LambdaTransition.new] = chain.start

          chain.start = new_start
          chain.final = new_final
        end
      end

      private def nfa_star(chain)
        if chain.start && chain.final
          new_final = state
          new_start = state
          new_final.transitions[LambdaTransition.new] = new_start
          new_start.transitions[LambdaTransition.new] = new_final
          chain.final.transitions[LambdaTransition.new] = new_final
          new_start.transitions[LambdaTransition.new] = chain.start

          chain.start = new_start
          chain.final = new_final
        end
      end

      private def nfa_question(chain)
        if chain.start && chain.final
          new_final = state
          new_start = state
          new_start.transitions[LambdaTransition.new] = new_final
          chain.final.transitions[LambdaTransition.new] = new_final
          new_start.transitions[LambdaTransition.new] = chain.start

          chain.start = new_start
          chain.final = new_final
        end
      end

      private def read_char(tokens)
        raise "Unexpected end of file"  unless tokens.first?
        char = tokens.delete_at(0)
        if char == '\\'
          raise "Invalid escape character" unless tokens.first?
          char = tokens.delete_at(0)
        end
        raise "Non-ASCII characters not supported" unless char.ascii?
        return char.bytes[0]
      end

      private def from_regex_range(tokens)
        tokens.delete_at(0)
        invert = false
        last_char = nil
        ranges = [] of Range(UInt8, UInt8)

        if tokens.first? == '^'
          invert = true
          tokens.delete_at(0)
        end

        while tokens.first? && tokens.first != ']'
          if tokens.first == '-'
            raise "Invalid range" unless last_char
            tokens.delete_at(0)
            ranges << (last_char..read_char(tokens))
            last_char = nil
          else
            last_char.try { |it| ranges << (it..it) }
            last_char = read_char(tokens)
          end
        end

        raise "Invalid range definition" if tokens.first? != ']'
        tokens.delete_at(0)
        
        start = state
        final = state
        start.transitions[RangeTransition.new(ranges, invert)] = final
        return StateChain.new(start, final)
      end

      private def from_regex_expr(tokens, *, require_parenths = true)
        substring_stack = [] of StateChain
        current_chain = nil
        sub_chain = nil

        if require_parenths
          tokens.delete_at(0)
        end

        modifiers = {
          '+' => ->nfa_plus(StateChain),
          '*' => ->nfa_star(StateChain),
          '?' => ->nfa_question(StateChain)
        }

        while tokens.first? && tokens.first != ')'
          char = tokens.first

          if modifier = modifiers[char]?
            tokens.delete_at(0)
            raise "Invalid operator" unless sub_chain
            modifier.call(sub_chain)
            next
          end

          current_chain = current_chain.try(&.append!(sub_chain)) || sub_chain
          if char == '('
            sub_chain = from_regex_expr(tokens)
          elsif char == '.'
            tokens.delete_at(0)
            empty_state = state
            actual_state = state

            empty_state.transitions[AnyTransition.new] = actual_state
            sub_chain = StateChain.new(empty_state, actual_state)
          elsif char == '|'
            tokens.delete_at(0)
            substring_stack.push current_chain if current_chain
            current_chain = nil
            sub_chain = nil
          elsif char == '['
            sub_chain = from_regex_range(tokens)
          else
            char = read_char(tokens)

            empty_state = state
            actual_state = state
            empty_state.transitions[ByteTransition.new char] = actual_state
            sub_chain = StateChain.new(empty_state, actual_state)
          end
        end
        current_chain = current_chain.try(&.append!(sub_chain)) || sub_chain

        if require_parenths && tokens.first? == ')'
          tokens.delete_at(0)
        elsif (require_parenths ^ (tokens.first? == ')'))
          raise "Mismatched parentheses"
        end

        if substring_stack.size > 0
          substring_stack.push current_chain if current_chain
          start_state = state
          end_state = state
          substring_stack.compact!.each do |chain|
            start_state.transitions[LambdaTransition.new] = chain.start
            chain.final.transitions[LambdaTransition.new] = end_state
          end
          current_chain = StateChain.new(start_state, end_state)
        end

        return current_chain
      end

      def add_regex(str, id)
        tokens = str.chars
        chain = from_regex_expr(tokens, require_parenths: false)
        final_state = state_for data: id
        final_chain = StateChain.new(final_state, final_state)
        new_start = (chain.try(&.append!(final_chain)) || final_chain).start
        @start.not_nil!.transitions[LambdaTransition.new] = new_start
      end
    end
  end
end
