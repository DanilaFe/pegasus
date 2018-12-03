require "./nfa.cr"
require "./error.cr"

module Pegasus
  module Nfa
    # A "unit" of one or more connected states.
    class StateChain
      # The beginning of this chain.
      property start : NState
      # The end of this chain.
      property final : NState

      # Creates a new chain with the given initial and final states.
      def initialize(@start, final = nil)
        @final = final || @start
      end

      # Appends another chain to this one, modifying the states' transition
      # hashes, too.
      def append!(other : StateChain)
        @final.not_nil!.transitions[LambdaTransition.new] = other.start.not_nil!
        @final = other.final
        return self
      end

      # Appends nothing to this chain. This is a no-op.
      def append!(other : Nil)
        return self
      end
    end

    class Nfa
      ESCAPES = {
        '\'' => 0x27_u8,
        '"'  => 0x22_u8,
        '?'  => 0x3f_u8,
        '\\' => 0x5c_u8,
        'a'  => 0x07_u8,
        'b'  => 0x08_u8,
        'f'  => 0x0c_u8,
        'n'  => 0x0a_u8,
        'r'  => 0x0d_u8,
        't'  => 0x09_u8,
        'v'  => 0x0b_u8,
        '*'  => 0x2a_u8,
        '+'  => 0x2b_u8,
        '-'  => 0x2d_u8,
        '|'  => 0x7c_u8,
        '['  => 0x5b_u8,
        ']'  => 0x5d_u8,
        '('  => 0x28_u8,
        ')'  => 0x29_u8,
        '.'  => 0x2e_u8,
      }

      # Applies the "+" operator to the given `StateChain`.
      private def nfa_plus(chain)
        new_final = state
        new_start = state
        new_final.transitions[LambdaTransition.new] = new_start
        chain.final.transitions[LambdaTransition.new] = new_final
        new_start.transitions[LambdaTransition.new] = chain.start

        chain.start = new_start
        chain.final = new_final
      end

      # Applies the "*" operator to the given `StateChain`.
      private def nfa_star(chain)
        new_final = state
        new_start = state
        new_final.transitions[LambdaTransition.new] = new_start
        new_start.transitions[LambdaTransition.new] = new_final
        chain.final.transitions[LambdaTransition.new] = new_final
        new_start.transitions[LambdaTransition.new] = chain.start

        chain.start = new_start
        chain.final = new_final
      end

      # Applies the "?" operator to the given `StateChain`.
      private def nfa_question(chain)
        new_final = state
        new_start = state
        new_start.transitions[LambdaTransition.new] = new_final
        chain.final.transitions[LambdaTransition.new] = new_final
        new_start.transitions[LambdaTransition.new] = chain.start

        chain.start = new_start
        chain.final = new_final
      end

      # Reas a character, taking into account the scape character.
      private def read_char(tokens)
        raise_nfa "Unexpected end of file"  unless tokens.first?
        char = tokens.delete_at(0)
        if char == '\\'
          raise_nfa "Incomplete escape character" unless tokens.first?
          char = tokens.delete_at(0)
          escape = ESCAPES[char]?
          raise_nfa "Invalid escape code" unless escape
          return escape
        else
          raise_nfa "Non-ASCII characters not supported" unless char.ascii?
          return char.bytes[0]
        end
      end

      # Creates an NFA chain using the range syntax ([...])
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
            raise_nfa "Invalid range" unless last_char
            tokens.delete_at(0)
            ranges << (last_char..read_char(tokens))
            last_char = nil
          else
            last_char.try { |it| ranges << (it..it) }
            last_char = read_char(tokens)
          end
        end
        last_char.try { |it| ranges << (it..it) }

        raise_nfa "Invalid range definition" if tokens.first? != ']'
        tokens.delete_at(0)

        start = state
        final = state
        start.transitions[RangeTransition.new(ranges, invert)] = final
        return StateChain.new(start, final)
      end

      # Parses a (sub)expression, optionally requiring parentheses.
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
            raise_nfa "Invalid operator" unless sub_chain
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
          raise_nfa "Mismatched parentheses"
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

      # Adds a regular expression branch to this Nfa.
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
