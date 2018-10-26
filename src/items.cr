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
      property lookahead : Set(Terminal)

      def initialize(@item, @lookahead, @index = 0_i64)
      end

      def ==(other : DottedItem)
        return (other.item == @item) && (other.index == @index) && (other.lookahead == @lookahead)
      end

      def hash(hasher)
        @item.hash(hasher)
        @index.hash(hasher)
        @lookahead.hash(hasher)
        hasher
      end

      def to_s(io)
          io << "DottedItem(" << item << ", " << index << ", {" << lookahead.map(&.to_s).join(", ") << "})"
      end
    end
  end
end
