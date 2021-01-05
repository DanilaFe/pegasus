require "./nfa.cr"
require "./pda.cr"
require "./error.cr"

module Pegasus
  module Dfa
    class ConflictErrorContext < Pegasus::Error::ErrorContext
      getter item_ids : Array(Int64)

      def initialize(@item_ids)
      end

      def to_s(io)
        io << "The IDs of the items involved are "
        @item_ids.join(io, ", ")
      end
    end

    class Dfa
      # Creates a final table, which is used to determine if a state matched a token.
      def final_table
        return [0_i64] + @states.map { |s| s.data.compact_map(&.data).max_of?(&.+(1)) || 0_i64 }
      end

      # Creates a transition table given, see `Pegasus::Language::LanguageData`
      def state_table
        table = [Array.new(256, 0_i64)]
        @states.each do |state|
          empty_table = Array.new(256, 0_i64)
          state.transitions.each do |byte, out_state|
            empty_table[byte] = out_state.id + 1
          end
          table << empty_table
        end
        return table
      end
    end
  end

  module Pda
    class LookaheadItem
      def insert_shift?(action_table, state)
        return if done?
        next_element = item.body[index]
        return if !next_element.is_a?(Elements::IndexableElement)

        previous_value = action_table[state.id + 1][next_element.table_index]
        if previous_value > 0
          raise_table "Shift / reduce conflict", context_data: [
            Pegasus::Dfa::ConflictErrorContext.new([ previous_value ])
          ]
        end
        action_table[state.id + 1][next_element.table_index] = 0
      end

      def insert_reduce?(action_table, state, self_index)
        return if !done?

        @lookahead.each do |terminal|
          next unless terminal.is_a?(Elements::IndexableElement)
          previous_value = action_table[state.id + 1][terminal.table_index]
          if previous_value == 0
            raise_table "Shift / reduce conflict", context_data: [
              Pegasus::Dfa::ConflictErrorContext.new([ self_index.to_i64  ])
            ]
          end
          if previous_value > 0
            raise_table "Reduce / reduce conflict", context_data: [
              Pegasus::Dfa::ConflictErrorContext.new([ previous_value - 1, self_index.to_i64  ])
            ]
          end
          action_table[state.id + 1][terminal.table_index] = self_index.to_i64 + 1
        end
      end
    end

    class Pda
      # Creates an action table, determing what the parser should do
      # at the given state and the lookhead token.
      def action_table
        last_terminal_index = @items.max_of? do |item|
          item.body.select(&.is_a?(Elements::IndexableElement)).max_of?(&.table_index) || 1_i64
        end || 0_i64

        # +1 Because the EOF token has its own spot, too.
        table = Array.new(@states.size + 1) { Array.new(last_terminal_index + 1, -1_i64) }
        @states.each do |state|
          state.data.each do |item|
            item.insert_shift?(table, state)
            item.insert_reduce?(table, state, @items.index(item.item).not_nil!)
          end
        end

        return table
      end

      # Creates a transition table that is indexed by both Terminals and Nonterminals.
      def state_table
        last_terminal_index = @items.max_of? do |item|
          item.body.select(&.is_a?(Elements::TerminalId)).max_of?(&.table_index) || 0_i64
        end || 0_i64

        last_nonterminal_index = @items.max_of? do |item|
          Math.max(item.head.table_index, item.body.select(&.is_a?(Elements::NonterminalId)).max_of?(&.table_index) || 0_i64)
        end || 0_i64

        # +1 Because the EOF token has its own spot, too.
        table = Array.new(@states.size + 1) { Array.new(last_terminal_index + last_nonterminal_index + 1, 0_i64) }
        @states.each do |state|
          state.transitions.each do |token, to|
            case token
            when Elements::IndexableElement
              table[state.id + 1][token.table_index] = to.id + 1
            when Elements::NonterminalId
              table[state.id + 1][token.table_index + last_terminal_index] = to.id + 1
            end
          end
        end

        return table
      end
    end
  end
end
