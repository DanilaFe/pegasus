module Pegasus
  module Language
    class LanguageDefinition
      enum ParseState
        Base,
        ParseHead,
        ParseEquals,
        ParseRegex,
        ParseId
        ParseBody
      end
      
      class TerminalRegex
        getter regex : String

        def initialize(@regex)
        end

        def to_s(io)
          io << "\"" << @regex << "\""
        end
      end

      class NonterminalName
        getter name : String

        def initialize(@name)
        end

        def to_s(io)
          io << @name
        end
      end

      class Declaration
        getter head : String
        getter bodies : Array(Array(TerminalRegex | NonterminalName))

        def initialize(@head, @bodies)
        end

        def to_s(io)
          io << head
          io << " = " << declarations.map do |decl|
            decl.map(&.to_s).join " "
          end.join "\n | "
        end
      end

      def initialize
        @declarations = [] of Declaration
      end

      def initialize(s : String)
        @declarations = [] of Declaration
        from_string(s)
      end

      def initialize(io : IO)
        @declarations = [] of Declaration
        from_io(io)
      end

      private def pop_while(chars, &block)
        while (char = chars.pop?) && yield char
        end
        chars.push char if char
      end

      private def read_name(chars)
        acc = ""
        pop_while chars, do |char|
         next false unless char.ascii_letter? || char.ascii_number? || char == '_'
         acc += char
         next true
        end
        return acc
      end

      private def hash_get(hash, key, &block)
        if hash.has_key? key
          return hash[key]
        end

        return (hash[key] = yield key)
      end

      private def visit_nonterminal(id, hash, name)
        hash_get(hash, name) do |n|
          id += 1
          Pegasus::Pda::Nonterminal.new (id - 1)
        end
        return id
      end

      private def visit_terminal(id, hash, name)
        hash_get(hash, name) do |n|
          id += 1
          Pegasus::Pda::Terminal.new (id - 1)
        end
        return id
      end

      private def find_nonterminals
        nonterminal_id = 0_i64
        nonterminals = {} of String => Pegasus::Pda::Nonterminal
        
        @declarations.each do |decl|
          nonterminal_id = visit_nonterminal(nonterminal_id, nonterminals, decl.head)
          decl.bodies.each do |body|
            body
              .select(&.is_a?(NonterminalName))
              .map(&.as(NonterminalName).name).each do |elem|
              nonterminal_id = visit_nonterminal(nonterminal_id, nonterminals, elem)
            end
          end
        end
        return nonterminals
      end

      private def find_terminals
        terminal_id = 0_i64
        terminals = {} of String => Pegasus::Pda::Terminal

        @declarations.each do |decl|
          decl.bodies.each do |body|
            body
              .select(&.is_a?(TerminalRegex))
              .map(&.as(TerminalRegex).regex).each do |elem|
              terminal_id = visit_terminal(terminal_id, terminals, elem)
            end
          end
        end
        return terminals
      end

      private def generate_grammar
        nonterminals = find_nonterminals
        terminals = find_terminals
        items = [] of Pegasus::Pda::Item
        @declarations.each do |decl|
          item_head = nonterminals[decl.head]
          decl.bodies.each do |body|
            item_body = body.map do |elem|
              case elem
              when NonterminalName
                next nonterminals[elem.name]
              when TerminalRegex
                next terminals[elem.regex]
              end
            end.map(&.not_nil!)

            items << Pegasus::Pda::Item.new item_head, item_body
          end
        end

        grammar = Pegasus::Pda::Grammar.new(terminals.values, nonterminals.values)
        items.each do |i|
          grammar.add_item i
        end

        return { terminals, nonterminals, grammar }
      end

      def generate
        terminals, nonterminals, grammar = generate_grammar
        nfa = Pegasus::Nfa::Nfa.new
        terminals.each do |regex, value|
          nfa.add_regex regex, value.id
        end
        dfa = nfa.dfa
        lex_state_table = dfa.state_table
        lex_final_table = dfa.final_table
        lr_pda = grammar.create_lr_pda(nonterminals.values.find { |it| it.id == 0 })
        lalr_pda = grammar.create_lalr_pda(lr_pda)
        parse_state_table = lalr_pda.state_table
        parse_action_table = lalr_pda.action_table
        return { lex_state_table, lex_final_table, parse_state_table, parse_action_table }
      end

      def from_string(string)
        chars = string.reverse.chars
        state = ParseState::Base
        current_head = ""
        current_alternatives = [] of Array(TerminalRegex | NonterminalName)
        current_body = [] of TerminalRegex | NonterminalName
        while !chars.empty?
          case state
          when ParseState::Base
            pop_while chars, &.ascii_whitespace?
            state = ParseState::ParseHead
          when ParseState::ParseHead
            pop_while chars, &.ascii_whitespace?
            current_head = read_name chars
            state = ParseState::ParseEquals
          when ParseState::ParseEquals
            pop_while chars, &.ascii_whitespace?
            raise "Invalid grammar declaration" unless chars.last? == '='
            chars.pop
            state = ParseState::ParseBody
          when ParseState::ParseBody
            pop_while chars, &.ascii_whitespace?
            char = chars.pop?
            next unless char
            
            if char == '"'
              acc = ""
              pop_while chars, do |char|
                next false if char == '"'
                if char == '\\'
                  char = chars.pop?
                  raise "Invalid escape code!" unless char
                end
                acc += char
                next true
              end
              raise "Invalid grammar declaration" unless chars.last? == '"'
              chars.pop

              current_body << TerminalRegex.new acc
            elsif char == '|'
              current_alternatives << current_body
              current_body = [] of TerminalRegex | NonterminalName
            elsif char == ';'
              current_alternatives << current_body
              current_body = [] of TerminalRegex | NonterminalName
              @declarations << Declaration.new current_head, current_alternatives
              current_alternatives = [] of Array(TerminalRegex | NonterminalName)
              state = ParseState::Base
            else
              chars.push char
              current_body << NonterminalName.new read_name(chars)
            end
          end
        end
      end

      def from_io(io)
        string = io.gets_to_end
        from_string(string)
      end
    end
  end
end
