module Pegasus
  module Pda
    class Terminal
      SPECIAL_EOF = -1_i64
      SPECIAL_EMPTY = -2_i64

      property id : Int64

      def initialize(@id)
      end

      def ==(other : Terminal)
        return @id == other.id
      end

      def hash(hasher)
        @id.hash(hasher)
        hasher
      end

      def to_s(io)
        io << "Terminal(" << @id << ")"
      end
    end

    class Nonterminal
      property id : Int64

      def initialize(@id)
      end

      def ==(other : Nonterminal)
        return @id == other.id
      end

      def hash(hasher)
        @id.hash(hasher)
        hasher
      end

      def to_s(io)
        io << "Nonterminal(" << @id << ")"
      end
    end

    alias Element = Terminal | Nonterminal
  end
end
