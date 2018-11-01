module Pegasus
  module Simulator
    class Token
      getter id : Int64
      getter string : String

      def initialize(@id, @string)
      end
    end

    class Tree
      getter id : Int64
      getter children : Array(Tree)
      getter token : Token?

      def initialize(@id, @children = [] of Tree)
      end
    end

    class Simulator
      alias TwoTable = Array(Array(Int64))
      alias OneTable = Array(Int64)

      def initialize(*, @lex_state_table : TwoTable, @lex_final_table : OneTable,
                     @parse_state_table : TwoTable, @parse_action_table : TwoTable)
      end

      private def lex(string)
        index = 0
        bytes = string.chars.map &.bytes[0]
        tokens = [] of Token
        failed = false
        while index < bytes.size
          state = 1
          start = index
          last_match = { -1_i64, -1_i64 }
          puts "Starting at #{index}"
          while state != 0 && index < bytes.size
            puts "#{state} -> #{@lex_state_table[state][bytes[index]]}"
            if (token = @lex_final_table[state]) != 0
              last_match = { index, token }
            end
            state = @lex_state_table[state][bytes[index]]
            index += 1 if state != 0
          end
          if (token = @lex_final_table[state]) != 0
            last_match = { index, token }
          end
          
          if last_match[0] < 0
            failed = true
            break
          end

          tokens << Token.new(last_match[1], string[start...last_match[0]])
        end

        raise "Invalid token" if failed
        return tokens
      end

      def simulate(string)
        tokens = lex(string)
      end
    end
  end
end
