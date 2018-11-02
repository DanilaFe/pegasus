module Pegasus
  module Pda
    class Terminal
      # Special ID used for the end-of-file character
      SPECIAL_EOF = -1_i64
      # Special ID used for the "empty" string in FIRST set computation
      SPECIAL_EMPTY = -2_i64

      # The ID of this terminal.
      getter id : Int64

      # Creates a new Terminal with the given ID.
      def initialize(@id)
      end

      # Compares this terminal to another terminal.
      def ==(other : Terminal)
        return @id == other.id
      end

      # Creates a hash of this Terminal.
      def hash(hasher)
        @id.hash(hasher)
        hasher
      end

      def to_s(io)
        io << "Terminal(" << @id << ")"
      end
    end

    class Nonterminal
      # The ID of this nonterminal.
      getter id : Int64

      # Creates a new Nonterminal with the given ID.
      def initialize(@id)
      end

      # Compares this nonterminal to another nonterminal.
      def ==(other : Nonterminal)
        return @id == other.id
      end

      # Creates a hash of this Nonterminal.
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
