module Pegasus
  module Dfa
    class Dfa
      def final_table
        return [0_i64] + @states.map { |s| s.data.compact_map(&.data).max_of?(&.+(1)) || 0_i64 }
      end

      def state_table
        table = [Array.new(256, 0_i64)]
        @states.each do |state|
          empty_table = Array.new(256, 0_i64)
          state.transitions.each do |byte, state|
            empty_table[byte] = state.id + 1
          end
          table << empty_table
        end
        return table
      end
    end
  end

  module Pda
    class Pda
      def action_table
        max_terminal = @items.max_of? do |item|
          item.body.select(&.is_a?(Terminal)).max_of?(&.id) || 0_i64
        end || 0_i64

        # +1 for potential -1, +1 since terminal IDs start at 0.
        table = Array.new(@states.size + 1) { |inded| Array.new(max_terminal + 1 + 1, 0_i64) }
        @states.each do |state|
          done_items = state.data.select &.done?
          done_items.each do |item|
            item.lookahead.each do |terminal|
              table[state.id + 1][terminal.id + 1] = @items.index(item.item).not_nil!.to_i64 + 1
            end
          end
        end
        
        return table
      end
      
      def state_table
        max_terminal = @items.max_of? do |item|
          item.body.select(&.is_a?(Terminal)).max_of?(&.id) || 0_i64
        end || 0_i64

        max_nonterminal = @items.max_of? do |item|
          Math.max(item.head.id, item.body.select(&.is_a?(Nonterminal)).max_of?(&.id) || 0_i64)
        end || 0_i64

        # +1 for potential -1 in terminal, +1 + 1 because both terminal and nonterminals start at 0.
        table = Array.new(@states.size + 1) { |i| Array.new(max_nonterminal + max_terminal + 1 + 1 + 1, 0_i64) }
        @states.each do |state|
          state.transitions.each do |token, to|
            case token
            when Terminal
              table[state.id + 1][token.id + 1] = to.id + 1
            when Nonterminal
              table[state.id + 1][token.id + 1 + 1 + max_terminal] = to.id + 1
            end
          end
        end

        return table
      end
    end
  end
end
