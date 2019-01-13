module Pegasus
  module Elements
    # An item that can be in a lookahead item's follow set.
    # This could be a terminal ID, or the special reserved EOF and "empty" (epsilon)
    # elements.
    abstract class LookaheadElement
    end

    # A lookahead element which can be used as in index to a lookup table.
    abstract class IndexableElement < LookaheadElement
      # Gets the table index of this element.
      abstract def table_index : Int64
    end

    # The special-case empty (epsilon) element used for follow set computation.
    class EmptyElement < LookaheadElement
      def ==(other : EmptyElement)
        return true
      end

      def ==(other : LookaheadElement)
        return false
      end

      def hash(hasher)
        hasher
      end
    end

    # The EOF element. Represents the end of the file, and is not matched as a token by the lexer.
    class EofElement < IndexableElement
      def table_index
        return 0_i64
      end

      def ==(other : EofElement)
        return true
      end

      def ==(other : LookaheadElement)
        return false
      end

      def hash(hasher)
        hasher
      end
    end

    # A terminal, as specified by the user. This is __not__ a special case element, and one terminal ID
    # exists for every token the user registers.
    class TerminalId < IndexableElement 
      def initialize(@id : Int64)
      end

      def table_index
        return @id + 1
      end

      # Gets the raw ID of this terminal. This should be used with caution.
      def raw_id
        return @id
      end

      def ==(other : TerminalId)
        return @id == other.@id
      end

      def ==(other : LookaheadElement)
        return false
      end

      def hash(hasher)
        @id.hash(hasher)
        hasher
      end
    end

    # A nonterminal, as specified by the user. Nonterminals are on the left of production rules (though they can also
    # appear on the right.
    class NonterminalId
      # Creates a new NonterminalId with the given ID.
      def initialize(@id : Int64, @start = false)
      end

      # Gets the table index of this nonterminal.
      def table_index
        return @id + 1
      end

      # Gets the raw ID of this nonterminal. This should be used with caution.
      def raw_id
        return @id
      end

      # Checks if this nonterminal is a "start" nonterminal (i.e., a potentially top level node)
      def start?
        return @start
      end

      # Compares this nonterminal to another nonterminal.
      def ==(other : NonterminalId)
        return (@id == other.@id) && (@start == other.@start)
      end

      # Creates a hash of this NonterminalId.
      def hash(hasher)
        @id.hash(hasher)
        @start.hash(hasher)
        hasher
      end

      def to_s(io)
        io << "NonterminalId(" << @id << ")"
      end
    end
  end
end
