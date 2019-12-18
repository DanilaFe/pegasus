require "./generated/semantics_parser.cr"

module Pegasus
  module Semantics
    alias NonterminalTree = Generated::Semantics::NonterminalTree
    alias TerminalTree = Generated::Semantics::TerminalTree

    class SemanticsData
      getter types : Hash(String, String)
      getter nonterminal_types : Hash(Elements::NonterminalId, String)
      getter actions : Hash(Int64, String)
      getter init : String

      def initialize(source, token_type : String, @data : Language::LanguageData)
        @types = {} of String => String
        @nonterminal_types = {} of Elements::NonterminalId => String
        @actions = {} of Int64 => String
        @init = ""

        @types["token"] = token_type

        begin
          raw_tree = Pegasus::Generated::Semantics.process(source).as(NonterminalTree)
        rescue e : Pegasus::Error::PegasusException
          raise e
        rescue e : Exception
          raise_general e.message.not_nil!
        end

        register_types raw_tree.children[0]
        register_typerules raw_tree.children[1]
        register_init raw_tree.children[2]
        register_rules raw_tree.children[3]
      end

      private def register_types(tree)
        type_list = tree.as(NonterminalTree)
        loop do
          type_decl = type_list.children[0].as(NonterminalTree)
          identifier = type_decl.children[1].as(TerminalTree).string;
          code = type_decl.children[3].as(TerminalTree).string[2..-3];
          raise_general "Redefining #{identifier}" if @types.includes? identifier
          @types[identifier] = code

          break if type_list.children.size == 1
          type_list = type_list.children[1].as(NonterminalTree)
        end
      end

      private def register_typerules(tree)
        typerules_list = tree.as(NonterminalTree)
        loop do
          typerule_decl = typerules_list.children[0].as(NonterminalTree)
          identifier = typerule_decl.children[1].as(TerminalTree).string
          nonterminals = read_identifier_list typerule_decl.children[4]

          nonterminals.each do |nonterminal_name|
            unless nonterminal = @data.nonterminals[nonterminal_name]? 
              raise_general "unknown nonterminal #{nonterminal_name}"
            end

            if @nonterminal_types.includes? nonterminal
              raise_general "redefinition of type for #{nonterminal_name}"
            end

            @nonterminal_types[nonterminal] = identifier
          end

          break if typerules_list.children.size == 1
          typerules_list = typerules_list.children[1].as(NonterminalTree)
        end
      end

      private def read_identifier_list(tree)
        list = tree.as(NonterminalTree)
        identifiers = [] of String
        loop do
          identifiers << list.children[0].as(TerminalTree).string

          break if list.children.size == 1
          list = list.children[2].as(NonterminalTree)
        end
        return identifiers
      end

      private def register_init(tree)
        @init = tree.as(NonterminalTree).children[2].as(TerminalTree).string[2..-3];
      end

      private def register_rules(tree)
        rules_list = tree.as(NonterminalTree)
        loop do
          rule = rules_list.children[0].as(NonterminalTree)
          identifier = rule.children[1].as(TerminalTree).string
          number = rule.children[3].as(TerminalTree).string.to_i64
          code = rule.children[6].as(TerminalTree).string[2..-3];
          
          unless nonterminal = @data.nonterminals[identifier]?
            raise_general "unknown rule #{nonterminal}"
          end

          index = 0
          set = false
          @data.items.each_with_index do |item, i|
            next unless item.head == nonterminal
            if index == number
              raise_general "redefinition of rule #{identifier}(#{number})" if @actions.includes? i.to_i64
              @actions[i.to_i64] = code
              set = true
              break
            end
            index += 1
          end
          raise_general "no rule #{identifier}(#{number})" unless set

          break if rules_list.children.size == 1
          rules_list = rules_list.children[1].as(NonterminalTree)
        end
      end
    end
  end
end
