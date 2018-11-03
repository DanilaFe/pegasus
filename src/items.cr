require "./elements.cr"

module Pegasus
  module Pda
    # An single production item, without a dot or any
    # kind of state.
    class Item
      # The nonterminal on the left of the production rule,
      # into which the right hand side is converted.
      getter head : Nonterminal
      # The body of terminals and nonterminals on the right
      # of the production rule.
      getter body : Array(Terminal | Nonterminal)

      # Creates a new item with the given head and body.
      def initialize(@head, @body)
      end

      # Compares equality with the given other item.
      def ==(other : Item)
        return (other.head == @head) && (other.body == @body)
      end

      # Hashes this item.
      def hash(hasher)
        @head.hash(hasher)
        @body.hash(hasher)
        hasher
      end

      def to_s(io)
          io << "Item(" << head << ", [" << body.map(&.to_s).join(", ")  << "])"
      end
    end

    # An item with a "dot", which keeps track of how far the item is
    # in terms of being parsed.
    class DottedItem
      # The production rule this dotted item wraps.
      getter item : Item
      # The index in the body of the production rule.
      getter index : Int64

      # Creates a new dotted item.
      def initialize(@item, @index = 0_i64)
      end

      # Compares this item to another dotted item, including the index.
      def ==(other : DottedItem)
        return (other.item == @item) && (other.index == @index)
      end

      # Hashes this dotted item.
      def hash(hasher)
        @item.hash(hasher)
        @index.hash(hasher)
        hasher
      end

      def to_s(io)
          io << "DottedItem(" << item << ", " << index
          io << ", COMPLETED" if index == @item.body.size
          io << ")"
      end

      # Turns this item into the next item assuming a shift took place.
      def next_item!
        if @index < @item.body.size
          @index += 1 
        else
          raise "Reached past the end of the item!"
        end
      end

      # Creates a new item assuming a shift took place.
      def next_item
        new = dup
        new.next_item!
        return new
      end

      # Checks if this dotted item is done.
      def done?
          return @index == @item.body.size
      end
    end

    # A superclass of the `DottedItem` which also
    # keeps a lookahead set to further distinguish it
    # in LR(1) parser construction.
    class LookaheadItem < DottedItem
      # The lookahead set of this dotted item.
      getter lookahead : Set(Terminal)

      # Creates a new lookahead dotted item.
      def initialize(@item, @lookahead, @index = 0_i64)
        super(@item, @index)
      end

      # Compares this dotted item to another dotted item.
      def ==(other : LookaheadItem)
        return super(other) && (other.lookahead == @lookahead)
      end

      # Hashes this dotted item.
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
