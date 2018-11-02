module Pegasus
  module Simulator
    class Token
      getter id : Int64
      getter string : String

      def initialize(@id, @string)
      end

      def to_s(io)
        io << "Token(#{@id}, #{string})"
      end
    end

    class Tree
      getter id : Int64
      getter children : Array(Tree)
      getter token : Token?

      def initialize(element, max_terminal, @children = [] of Tree)
        @id = 0
        set_id(element, max_terminal)
      end

      private def set_id(terminal : Token, max_terminal)
        @token = terminal
        @id = terminal.id
      end

      private def set_id(nonterminal : Pegasus::Pda::Nonterminal, max_terminal)
        @id = max_terminal + 1_i64 + 1_i64 + nonterminal.id
      end

      def to_s(io, indent = 0)
        indent.times do
          io << "  "
        end
        io << "Tree"
        io << token.to_s
        io.puts
        @children.each { |child| child.to_s(io, indent + 1) }
      end
    end

    class Simulator
      def initialize(@data : Pegasus::Language::LanguageData)
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
          while state != 0 && index < bytes.size
            if (token = @data.lex_final_table[state]) != 0
              last_match = { index, token }
            end
            state = @data.lex_state_table[state][bytes[index]]
            index += 1 if state != 0
          end
          if (token = @data.lex_final_table[state]) != 0
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

      private def parse(tokens)
        tree_stack = [] of Tree
        state_stack =  [ 1_i64 ]
        index = 0

        while state_stack.last? != 0 && tree_stack.last?.try(&.id) != (@data.max_terminal + 1 + 1)
          current_token = tokens[index]?
          action = @data.parse_action_table[state_stack.last][current_token.try(&.id) || 0_i64]
          if action == 0
            raise "Cannot shift on empty token" unless current_token
            tree_stack << Tree.new(current_token, @data.max_terminal)
            index += 1
          else
            item = @data.items[action - 1]
            children = [] of Tree
            item.body.size.times do
              children.insert(0, tree_stack.pop)
              state_stack.pop
            end
            tree_stack << Tree.new(item.head, @data.max_terminal, children)
          end
          state_stack << @data.parse_state_table[state_stack.last][tree_stack.last.id]
        end

        raise "Invalid syntax" unless (index == tokens.size) || (state_stack.last? == 0)

        return tree_stack.last
      end

      def simulate(string)
        tokens = lex(string)
        tokens.each do |token|
            puts "#{token.string} (#{token.id})"
        end
        puts parse(tokens)
      end
    end
  end
end
