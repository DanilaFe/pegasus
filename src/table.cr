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
end
