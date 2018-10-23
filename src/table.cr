module Pegasus
  module Nfa
    class Nfa
      def final_table
        return [0] + @states.map { |s| s.final_id || 0 }
      end

      def state_table
        table = [Array.new(255, 0_i64)]
        @states.each do |state|
          empty_table = Array.new(255, 0_i64)
          state.transitions
              .select(&.is_a?(ByteTransition))
              .map(&.as(ByteTransition))
              .each do |transition|
            empty_table[transition.byte] = transition.other.id + 1
          end
          table << empty_table
        end
        return table
      end
    end
  end
end
