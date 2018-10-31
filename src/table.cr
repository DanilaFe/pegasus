module Pegasus
  module Dfa
    class Dfa
      def final_table
        return [0] + @states.map { |s| s.data.compact_map(&.data).max? || 0 }
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

        table = Array.new(@states.size + 1) { |inded| Array.new(max_terminal + 1, 0_i64) }
        @states.each do |state|
          done_items = state.data.select &.done?
          done_items.each do |item|
            item.lookahead.each do |terminal|
              puts terminal.id
              table[state.id + 1][terminal.id + 1] = @items.index(item.item).not_nil!.to_i64
            end
          end
        end
        
        return table
      end
    end
  end
end
