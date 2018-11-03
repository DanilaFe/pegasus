require "./elements.cr"
require "./items.cr"
require "./grammar.cr"
require "./nfa.cr"
require "./regex.cr"
require "./nfa_to_dfa.cr"
require "./table.cr"

module Pegasus
  module Language
    # The complete data class, built to be all the information
    # needed to construct a parser generator.
    class LanguageData
      # The state table for the lexer, which is used for transitions
      # of the `Pegasus::Nfa::Nfa` during tokenizing.
      getter lex_state_table : Array(Array(Int64))
      # The table that maps a state ID to a token ID, used to
      # recognize that a match has occured.
      getter lex_final_table : Array(Int64)
      # Transition table for the LALR parser automaton, indexed
      # by terminal and nonterminal IDs.
      getter parse_state_table : Array(Array(Int64))
      # Action table indexed by the state and the lookahead item.
      # Used to determine what the parser should do in each state.
      getter parse_action_table : Array(Array(Int64))

      # The terminals, and their original names / regular expressions.
      getter terminals : Hash(String, Pegasus::Pda::Terminal)
      # The nonterminals, and their original names.
      getter nonterminals : Hash(String, Pegasus::Pda::Nonterminal)
      # The items in the language. Used for reducing / building up
      # trees once a reduce action is performed.
      getter items : Array(Pegasus::Pda::Item)
      # The highest terminal ID, used for correctly accessing the
      # tables indexed by both terminal and nonterminal IDs.
      getter max_terminal : Int64

      # Creates a new language data object.
      def initialize(*,
                     @lex_state_table,
                     @lex_final_table,
                     @parse_state_table,
                     @parse_action_table,
                     @terminals,
                     @nonterminals,
                     @items)
        @max_terminal = @terminals.values.max_of?(&.id) || 0_i64
      end
    end

    # The state for the grammar parser.
    enum ParseState
      # We're just eating blank spaces waiting for the grammar rule.
      Base, 
      # We're expecting the right hand side declaration of a production rule.
      ParseHead,
      # We're expecting an equal sign which sits between the head and body of the production.
      ParseEquals,
      # We're parsing the body of the grammar, which consists of zero or more tokens.
      ParseBody
    end

    # Simply a wrapper class to hold a regular expression
    # literal as specified by the user. This exists so that
    # the body is made up of two distinctive elements rather than strings.
    class TerminalRegex
      # The regular expression the user used to describe this terminal.
      getter regex : String

      # Creates an new temrinal with the given regular expression.
      def initialize(@regex)
      end

      def to_s(io)
        io << "\"" << @regex << "\""
      end
    end

    # Another wrapper, this time for the name of a nonterminal element.
    # See `TerminalRegex` for an explanation of why this exists.
    class NonterminalName
      # The name of this nonterminal.
      getter name : String

      # Creates a new nonterminal
      def initialize(@name)
      end

      def to_s(io)
        io << @name
      end
    end

    # A declaration of a grammar rule, including several bodies separated by the `|` character.
    class Declaration
      # The head of this declaration. This a string because it can only by nonterminal.
      getter head : String
      # The bodies of the declaration, each of which is a valid production rule body.
      getter bodies : Array(Array(TerminalRegex | NonterminalName))

      # Creates a new declaration with the given head and bodies.
      def initialize(@head, @bodies)
      end

      def to_s(io)
        io << head
        io << " = " << declarations.map do |decl|
          decl.map(&.to_s).join " "
        end.join "\n | "
      end
    end


    # A language definition parsed from a grammar string.
    class LanguageDefinition
      # Creates a new, empty language definition.
      def initialize
        @declarations = [] of Declaration
      end

      # Creates a new language definition from the given string.
      def initialize(s : String)
        @declarations = [] of Declaration
        from_string(s)
      end

      # Creates a new language definition from the given IO.
      def initialize(io : IO)
        @declarations = [] of Declaration
        from_io(io)
      end

      # Pops tokens from the stack until the bock returns false.
      private def pop_while(chars, &block)
        while (char = chars.pop?) && yield char
        end
        chars.push char if char
      end

      # Reads a nonterminal name from the given list of characters.
      private def read_name(chars)
        acc = ""
        pop_while chars, do |char|
         next false unless char.ascii_letter? || char.ascii_number? || char == '_'
         acc += char
         next true
        end
        return acc
      end

      # Gets a key from a hash, and if the key doesn't exist, generates it using the block.
      private def hash_get(hash, key, &block)
        if hash.has_key? key
          return hash[key]
        end

        return (hash[key] = yield key)
      end

      # Creates an entry for the given nonterminal name in the hash,
      # unless one exists.
      private def visit_nonterminal(id, hash, name)
        hash_get(hash, name) do
          id += 1
          Pegasus::Pda::Nonterminal.new (id - 1)
        end
        return id
      end

      # Creates an entry for the given terminal name in the hash,
      # unless one exists.
      private def visit_terminal(id, hash, name)
        hash_get(hash, name) do
          id += 1
          Pegasus::Pda::Terminal.new (id - 1)
        end
        return id
      end

      # Finds all the nonterminals in the list of declarations.
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

      # Finds all the terminals in the list of declarations.
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

      # Creates a grammar, returning it and the hashes with identifiers for
      # the terminals and nonterminals.
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

      # Generates a `LanguageData` object, thereby completing the task of Pegasus.
      def generate
        terminals, nonterminals, grammar = generate_grammar
        nfa = Pegasus::Nfa::Nfa.new
        terminals.each do |regex, value|
          nfa.add_regex regex, value.id
        end
        dfa = nfa.dfa
        lex_state_table = dfa.state_table
        lex_final_table = dfa.final_table
        items = grammar.items
        lr_pda = grammar.create_lr_pda(nonterminals.values.find { |it| it.id == 0 })
        lalr_pda = grammar.create_lalr_pda(lr_pda)
        parse_state_table = lalr_pda.state_table
        parse_action_table = lalr_pda.action_table
        return LanguageData.new(
            lex_state_table: lex_state_table,
            lex_final_table: lex_final_table,
            parse_state_table: parse_state_table,
            parse_action_table: parse_action_table,
            terminals: terminals,
            nonterminals: nonterminals,
            items: items)
      end

      # Creates a language definition from a string.
      private def from_string(string)
        chars = string.reverse.chars
        state = ParseState::Base
        current_head = ""
        current_alternatives = [] of Array(TerminalRegex | NonterminalName)
        current_body = [] of TerminalRegex | NonterminalName
        while !chars.empty?
          case state
          when ParseState::Base
            pop_while chars, &.ascii_whitespace?
            state = ParseState::ParseHead if chars.last?
          when ParseState::ParseHead
            pop_while chars, &.ascii_whitespace?
            current_head = read_name chars
            raise "Missing production left hand side" unless current_head.size > 0
            state = ParseState::ParseEquals
          when ParseState::ParseEquals
            pop_while chars, &.ascii_whitespace?
            raise "Missing equal sign in production" unless chars.last? == '='
            chars.pop
            state = ParseState::ParseBody
          when ParseState::ParseBody
            pop_while chars, &.ascii_whitespace?
            char = chars.pop?
            "Missing terminating semicolon" unless char

            if char == '"'
              acc = ""
              pop_while chars, do |string_char|
                next false if string_char == '"'
                if string_char == '\\'
                  string_char = chars.pop?
                  raise "Invalid escape code" unless string_char
                end
                acc += string_char
                next true
              end
              raise "Missing terminating quotation mark in regular expression" unless chars.last? == '"'
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
              chars.push char.not_nil!
              name = read_name(chars)
              next unless name.size > 0
              current_body << NonterminalName.new name
            end
          end
        end
      end

      # Creates a languge definition from IO.
      private def from_io(io)
        string = io.gets_to_end
        from_string(string)
      end
    end
  end
end
