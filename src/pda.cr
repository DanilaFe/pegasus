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

      def initialize(@item, @index = 0_i64)
      end

      def ==(other : DottedItem)
        return (other.item == @item) && (other.index == @index)
      end

      def hash(hasher)
        @item.hash(hasher)
        @index.hash(hasher)
        hasher
      end

      def to_s(io)
        io << "DottedItem(" << item << ", " << index << ")"
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
          first << Terminal.new(Terminal::SPECIAL_EMPTY)
          return true
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

      def compute_first
        first_sets = Hash(Element | Array(Element), Set(Terminal)).new
        @terminals.each { |t| first_sets[t] = Set { t } }
        @nonterminals.each { |nt| first_sets[nt] = Set(Terminal).new }
        change_occured = true

        while change_occured
          change_occured = false
          @items.each do |item|
            change_occured |= compute_alternative_first(first_sets, item.body)
            change_occured |= concat_watching(first_sets[item.head], first_sets[item.body])
          end
        end
        
        return first_sets
      end

      def compute_follow(start, first_sets = compute_first)
        follow_sets = Hash(Nonterminal, Set(Terminal)).new
        @nonterminals.each { |nt| follow_sets[nt] = Set(Terminal).new }
        follow_sets[start] << Terminal.new(Terminal::SPECIAL_EOF)
        change_occured = true

        while change_occured
          change_occured = false
          @items.each do |item|
            next if item.body.size == 0
            if item.body.last.is_a?(Nonterminal)
              change_occured |= concat_watching(follow_sets[item.body.last], follow_sets[item.head])
            end

            index = 0
            (0...item.body.size - 1).each do |index|
              next unless item.body[index].is_a?(Nonterminal)
              new_follow = first_sets[item.body[index...item.body.size]].dup
              if contains_empty(new_follow)
                new_follow.concat follow_sets[item.head]
                new_follow = new_follow.reject &.id.==(Terminal::SPECIAL_EMPTY)
              end
              change_occured |= concat_watching(follow_sets[item.body[index]], new_follow)
            end
          end
        end

        return follow_sets
      end

      private def new_dots(dots : Set(DottedItem))
        dots.map do |dot|
          next Set(DottedItem).new if dot.index >= dot.item.body.size
          next Set(DottedItem).new if dot.item.body[dot.index].is_a?(Terminal)
          next @items.select(&.head.==(dot.item.body[dot.index])).map { |it| DottedItem.new(it) }
        end.reduce(Set(DottedItem).new) do |set, list|
          set.concat list
        end
      end

      private def all_dots(dots : Set(DottedItem))
        found_dots = dots.dup
        while concat_watching(found_dots, new_dots(found_dots))
        end
        return found_dots
      end

      private def all_dots(dot : DottedItem)
        return all_dots(Set{ dot })
      end

      def add_item(i)
        items << i
      end
    end
  end
end
