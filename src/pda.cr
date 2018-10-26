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

      def ==(other : Terminal)
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

    class Grammar
      property items : Set(Item)
      property terminals : Array(Terminal)
      property nonterminals : Array(Nonterminal)

      def initialize(@terminals, @nonterminals)
        @last_id = 0_i64
        @items = Set(Item).new
      end

      private def contains_empty(set)
        return set.select(&.id.==(Terminal::SPECIAL_EMPTY)).size != 0
      end

      private def concat_watching(set, other)
        initial_size = set.size
        set.concat other
        return initial_size != set.size
      end

      private def compute_alternative_first(first_sets, alternative)
        if !first_sets.has_key? alternative
          first = Set(Terminal).new
          first_sets[alternative] = first
        else
          first = first_sets[alternative]
        end

        if alternative.size == 0
          return false
        end

        start_element = alternative.first
        add_first = first_sets[start_element].dup
        if contains_empty(first)
            tail = alternative[1...alternative.size]
            compute_alternative_first(first_sets, tail)
            add_first.concat first_sets[tail]
        else
            add_first = add_first.reject &.id.==(Terminal::SPECIAL_EMPTY)
        end

        return concat_watching(first, add_first)
      end

      private def compute_alternatives_first(first_sets, body)
        change_occured = false
        body.size.times do |time|
          change_occured |= compute_alternative_first(first_sets, body[time...body.size])
        end
        return change_occured
      end

      def compute_first
        first_sets = Hash(Element | Array(Element), Set(Terminal)).new
        @terminals.each { |t| first_sets[t] = Set { t } }
        @nonterminals.each { |nt| first_sets[nt] = Set(Terminal).new }
        first_sets[[] of Element] = Set { Terminal.new(Terminal::SPECIAL_EMPTY) }
        change_occured = true

        while change_occured
          change_occured = false
          @items.each do |item|
            change_occured |= compute_alternatives_first(first_sets, item.body)
            change_occured |= concat_watching(first_sets[item.head], first_sets[item.body])
          end
        end
        
        return first_sets
      end

      private def get_lookahead(first_sets, alternative, old_lookahead)
        lookahead = first_sets[alternative].dup
        if contains_empty(lookahead)
          lookahead.concat(old_lookahead)
          lookahead = lookahead.reject &.id.==(Terminal::SPECIAL_EMPTY)
        end
        return lookahead.to_set
      end

      private def create_dotted_items(first_sets, nonterminal, suffix, parent_lookahead)
          return @items.select(&.head.==(nonterminal))
                      .map { |it| DottedItem.new it, get_lookahead(first_sets, suffix, parent_lookahead) }
      end

      private def new_dots(first_sets, dots)
        dots.map do |dot|
          next Set(DottedItem).new if dot.index >= dot.item.body.size
          next Set(DottedItem).new if dot.item.body[dot.index].is_a?(Terminal)
          next create_dotted_items(first_sets, dot.item.body[dot.index], dot.item.body[(dot.index+1)...dot.item.body.size], dot.lookahead)
        end.reduce(Set(DottedItem).new) do |set, list|
          set.concat list
        end
      end

      def all_dots(first_sets, dots)
        found_dots = dots.dup
        while concat_watching(found_dots, new_dots(first_sets, dots))
        end
        return found_dots
      end

      def create_pda(start)
        first_sets = compute_first
        start_items = all_dots(@items.select &.head.==(start))
      end

      def add_item(i)
        items << i
      end
    end
  end
end
