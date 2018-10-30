require "./elements.cr"

module Pegasus
  module Pda
    class Item
      property head : Nonterminal
      property body : Array(Terminal | Nonterminal)

      def initialize(@head, @body)
      end

      def ==(other : Item)
        return (other.head == @head) && (other.body == @body)
      end

      def hash(hasher)
        @head.hash(hasher)
        @body.hash(hasher)
        hasher
      end

      def to_s(io)
          io << "Item(" << head << ", [" << body.map(&.to_s).join(", ")  << "])"
      end
    end

    class DottedItem
      property item : Item
      property index : Int64

      def initialize(@item, @index = 0_i64)
      end

      def ==(other : DottedItem)
        return (other.item == @item) && (other.index == @index)
      end

      def to_s(io)
          io << "DottedItem(" << item << ", " << index
          io << ", COMPLETED" if index == @item.body.size
          io << ")"
      end

      def hash(hasher)
        @item.hash(hasher)
        @index.hash(hasher)
        hasher
      end

      def next_item
        new = dup
        new.index += 1 if new.index < new.item.body.size
        return new
      end
    end

    class LookaheadItem < DottedItem
      property lookahead : Set(Terminal)

      def initialize(@item, @lookahead, @index = 0_i64)
        super(@item, @index)
      end

      def ==(other : LookaheadItem)
        return super(other) && (other.lookahead == @lookahead)
      end

      def hash(hasher)
        super(hasher)
        @lookahead.hash(hasher)
        hasher
      end

      def to_s(io)
          io << "LookaheadItem(" << item << ", " << index << ", {" << lookahead.map(&.to_s).join(", ") << "}"
          io << ", COMPLETED" if index == @item.body.size
          io << ")"
      end
    end
  end
end
