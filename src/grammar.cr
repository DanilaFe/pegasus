require "./elements.cr"
require "./items.cr"

module Pegasus
  module Pda
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

      private def all_dots(first_sets, dots)
        found_dots = dots.to_set.dup
        while concat_watching(found_dots, new_dots(first_sets, found_dots))
        end
        groups = found_dots.group_by { |dot| { dot.item, dot.index } }
        found_dots = groups.map do |k, v|
          item, index = k
          merged_lookahead = v.map(&.lookahead).reduce(Set(Terminal).new) { |l, r| l.concat r }
          DottedItem.new item, merged_lookahead, index
        end
        return found_dots.to_set
      end

      def get_transitions(dotted_items)
        return dotted_items.compact_map do |dot|
            next nil unless dot.index < dot.item.body.size
            next { dot.item.body[dot.index], dot.next_item }
        end.reduce(Hash(Element, Set(DottedItem)).new) do |hash, kv|
           k, v = kv
           hash[k] = hash[k]?.try(&.<<(v)) || Set { v }
           next hash
        end
      end

      def create_pda(start)
        pda = Pda.new
        first_sets = compute_first
        # Set of items starting with the start nonterminal
        start_items = @items.select(&.head.==(start)).map do |it| 
            DottedItem.new it, Set { Terminal.new(Terminal::SPECIAL_EOF) }
        end.to_set
        # Set of all current dotted items
        all_start_items = all_dots(first_sets,  start_items)
        # Set of dotted items => corresponding state
        states = Hash(Set(DottedItem), PState).new

        queue = Set(Set(DottedItem)).new
        finished = Set(Set(DottedItem)).new

        queue << all_start_items

        while !queue.empty?
          dotted_items = queue.first
          queue.delete dotted_items
          next if finished.includes? dotted_items

          finished << dotted_items
          state = pda.state_for(data: dotted_items)
          transitions = get_transitions(dotted_items)
          transitions.each do |transition, items|
            items = all_dots(first_sets, items)
            new_state = pda.state_for data: dotted_items
            state.transitions[transition] = new_state
            queue << items
          end
        end

        return pda
      end

      def add_item(i)
        items << i
      end
    end
  end
end
