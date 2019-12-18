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
  # This module is for handling language data. The language is given by the complete
  # Pegasus grammar, and includes the terminals, nonterminals, and other rules.
  # This module also contains `LanguageData`, which is the JSON structure
  # that is passed between pegasus and its consumer programs, like pegasus-c.
  module Language
    # An error context which reports the items involved in some kind of conflict
    # (shift / reduce or reduce / reduce). This version, unlike `ConflictErrorContext`,
    # reports the relevant items' names.
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
      # Table for tokens that should be skipped.
      getter lex_skip_table : Array(Bool)
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
      # The table that maps a nonterminal ID to recognize
      # when parsing can stop.
      getter parse_final_table : Array(Bool)

      # The terminals, and their original names / regular expressions.
      getter terminals : Hash(String, Pegasus::Elements::TerminalId)
      # The nonterminals, and their original names.
      getter nonterminals : Hash(String, Pegasus::Elements::NonterminalId)
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
        @lex_skip_table, @lex_state_table, @lex_final_table,
          @parse_state_table, @parse_action_table, @parse_final_table =
          generate_tables(language_definition, @terminals, @nonterminals, grammar)
        @max_terminal = @terminals.values.max_of?(&.raw_id) || 0_i64
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
          Pegasus::Elements::TerminalId.new i
        end
        rule_ids = assign_ids(language_def.rules.keys) do |i|
          Pegasus::Elements::NonterminalId.new i, start: i == 0
        end

        grammar = Pegasus::Pda::Grammar.new token_ids.values, rule_ids.values
        language_def.rules.each do |name, bodies|
          head = rule_ids[name]
          bodies.each &.alternatives.each do |body|
            body = body.elements.map(&.name).map do |element_name|
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
      private def generate_tables(language_def, terminals, nonterminals, grammar)
        nfa = Pegasus::Nfa::Nfa.new
        terminals.each do |terminal, value|
          nfa.add_regex language_def.tokens[terminal].regex, value.raw_id
        end
        dfa = nfa.dfa

        begin
          lex_skip_table = [ false ] +
            language_def.tokens.map &.[1].options.includes?("skip")
          lex_state_table = dfa.state_table
          lex_final_table = dfa.final_table

          lr_pda = grammar.create_lr_pda
          lalr_pda = grammar.create_lalr_pda(lr_pda)
          parse_state_table = lalr_pda.state_table
          parse_action_table = lalr_pda.action_table
          parse_final_table = [false] + nonterminals.map &.[1].final?
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

        return { lex_skip_table, lex_state_table, lex_final_table, parse_state_table, parse_action_table, parse_final_table }
      end
    end

    class Pegasus::Generated::Tree
      alias SelfDeque = Deque(Pegasus::Generated::Tree)

      # Recursive call for the `#flatten` function.
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

    alias Option = String
    
    # Since Pegasus supports options on tokens and rules,
    # we need to represent an object to which options can be attached.
    # this is this type of object.
    abstract class OptionObject
      # Gets the actual list of options attached to this object.
      getter options : Array(Option)

      def initialize
        @options = [] of Option
      end
    end

    # A token declaration, with zero or more rules attached to it.
    class Token < OptionObject
      # Gets the regular expression that defines this token.
      getter regex : String

      def initialize(@regex, @options = [] of Option)
      end

      def ==(other : Token)
        return (other.regex == @regex) && (other.options == @options)
      end

      def hash(hasher)
        @regex.hash(hasher)
        @options.hash(hasher)
        hasher
      end
    end

    class ::Array(T)
      # Gets the indices of all values matching the condition
      def indices(&block)
        deque = Deque(Int32).new
        each_with_index do |v, i|
          deque << i if yield v
        end
        return deque.to_a
      end
    end

    module ::Iterable(T)
      def power_set
        set = Set(Set(T)).new
        set << Set(T).new

        each do |item|
          to_add = Set(Set(T)).new
          set.each do |subset|
            to_add << subset.dup.<<(item)
          end
          set.concat to_add
        end

        return set
      end
    end

    # An element of a grammar rule. Can be either a token or another rule.
    class RuleElement
      # The name of the element, as specified in the grammar.
      getter name : String

      def initialize(@name)
      end

      def ==(other : RuleElement)
        return @name == other.name
      end

      # If called in a child class of RuleElement,
      # this strips the child class of its additional data,
      # turning it back into a RuleElement base class.
      def base_element
        return self
      end

      # Checks if this element derives lambda.
      # This doesm't check if the production rule it
      # represent can derive lambda; rather, it checks
      # if this element has an operator applied to it
      # that makes it do so, like ? or *
      def derives_lambda?
        return false
      end
    end

    # An element that is optional.
    class OptionalElement < RuleElement
      def base_element
        return RuleElement.new name
      end

      def derives_lambda?
        return true
      end
    end

    # An element that is repeated one or more times.
    class OneOrMoreElement < RuleElement
    end

    # An element that is repeated zero or more times.
    class ZeroOrMoreElement < RuleElement
      def derives_lambda?
        return true
      end
    end

    # One of the alternatives of a rule. 
    class RuleAlternative
      # The elements of the rule.
      getter elements : Array(RuleElement)

      def initialize(@elements)
        raise_grammar "Empty productions are currently not supported" if elements.empty?
      end

      def ==(other : RuleAlternative)
        return @elements == other.elements
      end

      # Computes a single variant, given optional indices that should be included.
      private def compute_variant(indices)
        new_elements = [] of RuleElement
        elements.each_with_index do |element, index|
          next if element.derives_lambda? && !indices.includes? index
          new_elements << element.base_element
        end
        return RuleAlternative.new(new_elements)
      end

      # Checks if this specific alternative is the lambda alternative.
      def lambda?
        return @elements.empty?
      end

      # Determines if this rule alternative can be empty, or derive lambda.
      def derives_lambda?
        return derives_lambda? &.derives_lambda?
      end

      # Determines if the rule alternative can be empty, using
      # the block to check whether each element can be empty or not.
      def derives_lambda?(&block)
        return @elements.all? { |it| yield it }
      end

      # Computes the variants created by optionals.
      # For example, a? b? has four variants, a b, a, b, <empty>.
      def compute_optional_variants
        return compute_optional_variants &.derives_lambda?
      end

      # Same as compute_optional_variants, but what's optional is
      # now decided by the block.
      def compute_optional_variants(&block)
        optional_positions = @elements.indices { |it| yield it }
        power_set = optional_positions.power_set
        return power_set.map { |it| compute_variant(it) }
      end
    end

    # A single rule. This can have one or more alternatives,
    # but has the same options (zero or more) applied to them.
    class Rule < OptionObject
      getter alternatives : Array(RuleAlternative)

      def initialize(@alternatives, @options = [] of Option)
      end

      def ==(other : Rule)
        return (other.alternatives == @alternatives) && (other.options == @options)
      end

      def hash(hasher)
        @alternatives.hash(hasher)
        @options.hash(hasher)
        hasher
      end

      # Checks if this rule has any alternatives that can derive lambda.
      def derives_lambda?
        return @alternatives.any? &.derives_lambda?
      end

      # Checks if this rule has any alternatives that can derive lambda,
      # using a custom block for checking if an element can derive lambda.
      def derives_lambda?(&block)
        return @alternatives.any? &.derives_lambda? { |it| yield it }
      end

      # Creates a new rule with the same options, but with alternatives expanded for optional values.
      def compute_optional_variants
        return Rule.new(@alternatives.flat_map &.compute_optional_variants, @options)
      end

      # Creates a new rule with the same options, but with alternatives expanded for optional values.
      # Uses a custom block to check if the elements can be empty or not.
      def compute_optional_variants(&block)
        return Rule.new(@alternatives.flat_map &.compute_optional_variants(block), @options)
      end
    end

    # A language definition parsed from a grammar string.
    class LanguageDefinition
      getter tokens : Hash(String, Token)
      getter rules : Hash(String, Array(Rule))

      # Creates a new, empty language definition.
      def initialize
        @tokens = {} of String => Token
        @rules = {} of String => Array(Rule)
      end

      # Creates a new language definition from the given string.
      def initialize(s : String)
        @tokens = {} of String => Token
        @rules = {} of String => Array(Rule)
        from_string(s)
      end

      # Creates a new language definition from the given IO.
      def initialize(io : IO)
        @tokens = {} of String => Token
        @rules = {} of String => Array(Rule)
        from_io(io)
      end

      # Creates a list of options from a "statemend end" parse tree node.
      private def extract_options(statement_end_tree)
        statement_end_tree = statement_end_tree.as(Pegasus::Generated::NonterminalTree)
        return [] of Option unless statement_end_tree.children.size > 1
        options_tree = statement_end_tree.children[0].as(Pegasus::Generated::NonterminalTree)
        options = options_tree.children[1]
          .flatten(value_index: 0, recursive_name: "option_list", recursive_index: 2)
          .map(&.as(Pegasus::Generated::NonterminalTree).children[0])
          .map(&.as(Pegasus::Generated::TerminalTree).string)
      end

      # Extracts all the tokens from the token list parse tree node, storing them
      # in a member variable hash.
      private def extract_tokens(token_list_tree)
        token_list_tree.flatten(value_index: 0, recursive_name: "token_list", recursive_index: 1)
          .map { |it| ntt = it.as(Pegasus::Generated::NonterminalTree); { ntt.children[1], ntt.children[3], ntt.children[4] } }
          .map do |data|
            name_tree, regex_tree, statement_end = data
            name = name_tree
              .as(Pegasus::Generated::TerminalTree).string
            raise_grammar "Declaring a token (#{name}) a second time" if @tokens.has_key? name
            regex = regex_tree
              .as(Pegasus::Generated::TerminalTree).string[1..-2]
            @tokens[name] = Token.new regex, extract_options(statement_end)
          end
      end

      private def extract_rule_element(grammar_element_tree)
        grammar_element_tree = grammar_element_tree.as(Pegasus::Generated::NonterminalTree)
        name = grammar_element_tree.children[0].as(Pegasus::Generated::TerminalTree).string
        setting = grammar_element_tree.children[1]?.try { |it| it.as(Pegasus::Generated::TerminalTree).string }
        return case setting
               when "?"
                 OptionalElement.new name
               else
                 RuleElement.new name
               end
      end

      # Extracts all the body definitions from the grammar bodies tree node.
      # A rule has several bodies.
      private def extract_bodies(bodies_tree)
        bodies_tree.flatten(value_index: 0, recursive_name: "grammar_bodies", recursive_index: 2)
          .map do |body|
            RuleAlternative.new body
              .flatten(value_index: 0, recursive_name: "grammar_body", recursive_index: 1)
              .map { |it| extract_rule_element(it) }
        end
      end

      # Extracts all the rules from a gramamr list tree node, storin them
      # in a member variable hash.
      private def extract_rules(grammar_list_tree)
        grammar_list_tree.flatten(value_index: 0, recursive_name: "grammar_list", recursive_index: 1)
          .map { |it| ntt = it.as(Pegasus::Generated::NonterminalTree); { ntt.children[1], ntt.children[3], ntt.children[4] } }
          .map do |data|
            name_tree, bodies_tree, statement_end = data
            name = name_tree
              .as(Pegasus::Generated::TerminalTree).string
            raise_grammar "Declaring a rule (#{name}) with the same name as a token" if @tokens.has_key? name
            bodies = extract_bodies(bodies_tree)

            unless old_rules = @rules[name]?
              @rules[name] = old_rules = Array(Rule).new
            end
            old_rules << Rule.new(bodies, extract_options(statement_end)).compute_optional_variants
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
