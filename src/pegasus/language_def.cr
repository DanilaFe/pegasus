require "./elements.cr"
require "./items.cr"
require "./grammar.cr"
require "./nfa.cr"
require "./regex.cr"
require "./nfa_to_dfa.cr"
require "./table.cr"
require "./error.cr"
require "./generated/grammar_parser.cr"

module Pegasus
  module Language
    class NamedConflictErrorContext < Pegasus::Error::ErrorContext
      def initialize(@nonterminals : Array(String))
      end

      def to_s(io)
        io << "The nonterminals involved are: "
        @nonterminals.join(", ", io)
      end
    end

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
      def initialize(language_definition)
        @terminals, @nonterminals, grammar =
          generate_grammar(language_definition)
        @lex_state_table, @lex_final_table, @parse_state_table, @parse_action_table =
          generate_tables(@terminals.transform_keys { |it| language_definition.tokens[it] }, @nonterminals, grammar)
        @max_terminal = @terminals.values.max_of?(&.id) || 0_i64
        @items = grammar.items
      end

      # Assigns an ID to each unique vaue in the iterable.
      private def assign_ids(values : Iterable(T), &block : Int64 -> R) forall T, R
        hash = {} of T => R
        last_id = 0_i64
        values.each do |value|
          next if hash[value]?
          hash[value] = yield (last_id += 1) - 1
        end
        return hash
      end

      # Creates a grammar, returning it and the hashes with identifiers for
      # the terminals and nonterminals.
      private def generate_grammar(language_def)
        token_ids = assign_ids(language_def.tokens.keys) do |i|
          Pegasus::Pda::Terminal.new i
        end
        rule_ids = assign_ids(language_def.rules.keys) do |i|
          Pegasus::Pda::Nonterminal.new i
        end

        grammar = Pegasus::Pda::Grammar.new token_ids.values, rule_ids.values
        language_def.rules.each do |name, bodies|
          head = rule_ids[name]
          bodies.each do |body|
            body = body.map do |element_name|
              element = token_ids[element_name]? || rule_ids[element_name]?
              raise_grammar "No terminal or rule named #{element_name}" unless element
              next element
            end
            item = Pegasus::Pda::Item.new head, body
            grammar.add_item item
          end
        end

        return { token_ids, rule_ids, grammar }
      end

      # Generates lookup tables using the given terminals, nonterminals,
      # and grammar.
      private def generate_tables(terminals, nonterminals, grammar)
        nfa = Pegasus::Nfa::Nfa.new
        terminals.each do |regex, value|
          nfa.add_regex regex, value.id
        end
        dfa = nfa.dfa

        begin
          lex_state_table = dfa.state_table
          lex_final_table = dfa.final_table

          lr_pda = grammar.create_lr_pda(nonterminals.values.find { |it| it.id == 0 })
          lalr_pda = grammar.create_lalr_pda(lr_pda)
          parse_state_table = lalr_pda.state_table
          parse_action_table = lalr_pda.action_table
        rescue e : Pegasus::Error::PegasusException
          if old_context = e.context_data
            .find(&.is_a?(Pegasus::Dfa::ConflictErrorContext))
            .as?(Pegasus::Dfa::ConflictErrorContext)

            names = old_context.item_ids.map do |id|
              head = grammar.items[id].head
              nonterminals.key_for head
            end
            e.context_data.delete old_context
            e.context_data << NamedConflictErrorContext.new names
          end
          raise e
        end

        return { lex_state_table, lex_final_table, parse_state_table, parse_action_table }
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

    class Pegasus::Generated::Tree
      alias SelfDeque = Deque(Pegasus::Generated::Tree)

      protected def flatten_recursive(*, value_index : Int32, recursive_name : String, recursive_index : Int32) : SelfDeque
        if flattened = self.as?(Pegasus::Generated::NonterminalTree)
          recursive_child = flattened.children[recursive_index]?
          value_child = flattened.children[value_index]?

          if flattened.name == recursive_name && recursive_child
            add_to = recursive_child.flatten_recursive(
              value_index: value_index,
              recursive_name: recursive_name,
              recursive_index: recursive_index)
          else
            add_to = SelfDeque.new
          end
          add_to.insert(0, value_child) if value_child

          return add_to
        end
        return SelfDeque.new
      end

      # Since currently, * and + operators aren't supported in Pegasus grammars, they tend to be recursively written.
      # This is a utility function to "flatten" a parse tree produced by a recursively written grammar.
      def flatten(*, value_index : Int32, recursive_name : String, recursive_index : Int32)
        flatten_recursive(
          value_index: value_index,
          recursive_name: recursive_name,
          recursive_index: recursive_index).to_a
      end
    end

    # A language definition parsed from a grammar string.
    class LanguageDefinition
      getter tokens : Hash(String, String)
      getter rules : Hash(String, Array(Array(String)))

      # Creates a new, empty language definition.
      def initialize
        @tokens = {} of String => String
        @rules = {} of String => Array(Array(String))
      end

      # Creates a new language definition from the given string.
      def initialize(s : String)
        @tokens = {} of String => String
        @rules = {} of String => Array(Array(String))
        from_string(s)
      end

      # Creates a new language definition from the given IO.
      def initialize(io : IO)
        @tokens = {} of String => String
        @rules = {} of String => Array(Array(String))
        from_io(io)
      end

      private def extract_tokens(token_list_tree)
        token_list_tree.flatten(value_index: 0, recursive_name: "token_list", recursive_index: 1)
          .map { |it| ntt = it.as(Pegasus::Generated::NonterminalTree); { ntt.children[2], ntt.children[4] } }
          .map do |pair|
            name_tree, regex_tree = pair
            name = name_tree
              .as(Pegasus::Generated::TerminalTree).string
            raise_grammar "Declaring a token (#{name}) a second time" if @tokens.has_key? name
            regex = regex_tree
              .as(Pegasus::Generated::TerminalTree).string[1..-2]
            @tokens[name] = regex
          end
      end

      private def extract_bodies(bodies_tree)
        bodies_tree.flatten(value_index: 0, recursive_name: "grammar_bodies", recursive_index: 2)
          .map do |body|
            body
              .flatten(value_index: 0, recursive_name: "grammar_body", recursive_index: 2)
              .map(&.as(Pegasus::Generated::TerminalTree).string)
          end
      end

      private def extract_rules(grammar_list_tree)
        grammar_list_tree.flatten(value_index: 0, recursive_name: "grammar_list", recursive_index: 1)
          .map { |it| ntt = it.as(Pegasus::Generated::NonterminalTree); { ntt.children[2], ntt.children[4] } }
          .map do |pair|
            name_tree, bodies_tree = pair
            name = name_tree
              .as(Pegasus::Generated::TerminalTree).string
            raise_grammar "Declaring a rule (#{name}) with the same name as a token" if @tokens.has_key? name
            bodies = extract_bodies(bodies_tree)
            @rules[name] = @rules[name]?.try &.concat(bodies) || bodies
          end
      end

      # Creates a language definition from a string.
      private def from_string(string)
        tree = Pegasus::Generated.process(string).as(Pegasus::Generated::NonterminalTree)
        if tokens = tree.children.find &.as(Pegasus::Generated::NonterminalTree).name.==("token_list")
          extract_tokens(tokens)
        end
        if rules = tree.children.find &.as(Pegasus::Generated::NonterminalTree).name.==("grammar_list")
          extract_rules(rules)
        end
      rescue e : Pegasus::Error::PegasusException
        raise e
      rescue e : Exception
        raise_grammar e.message.not_nil!
      end

      # Creates a languge definition from IO.
      private def from_io(io)
        string = io.gets_to_end
        from_string(string)
      end
    end
  end
end
