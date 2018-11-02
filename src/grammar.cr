require "./elements.cr"
require "./items.cr"
require "./pda.cr"

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
                      .map { |it| LookaheadItem.new it, get_lookahead(first_sets, suffix, parent_lookahead) }
      end

      private def new_dots(first_sets, dots)
        dots.map do |dot|
          next Set(LookaheadItem).new if dot.index >= dot.item.body.size
          next Set(LookaheadItem).new if dot.item.body[dot.index].is_a?(Terminal)
          next create_dotted_items(first_sets, dot.item.body[dot.index], dot.item.body[(dot.index+1)...dot.item.body.size], dot.lookahead)
        end.reduce(Set(LookaheadItem).new) do |set, list|
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
          LookaheadItem.new item, merged_lookahead, index
        end
        return found_dots.to_set
      end

      def get_transitions(dotted_items)
        return dotted_items.compact_map do |dot|
            next nil unless dot.index < dot.item.body.size
            next { dot.item.body[dot.index], dot.next_item }
        end.reduce(Hash(Element, Set(LookaheadItem)).new) do |hash, kv|
           k, v = kv
           hash[k] = hash[k]?.try(&.<<(v)) || Set { v }
           next hash
        end
      end

      def create_lalr_pda(lr_pda)
        lalr_pda = Pda.new @items
        groups = lr_pda.states.group_by { |s| s.data.map { |it| DottedItem.new it.item, it.index }.to_set }
        states = Hash(typeof(lr_pda.states.first), typeof(lalr_pda.states.first)).new
        groups.each do |_, equal_states|
          item_groups = equal_states
              .flat_map(&.data.each)
              .group_by { |it| DottedItem.new it.item, it.index }
          merged_items = item_groups.map do |kv|
            dotted_item, items = kv
            LookaheadItem.new dotted_item.item, items.flat_map(&.lookahead.each).to_set, dotted_item.index
          end.to_set
          new_state = lalr_pda.state_for data: merged_items
          equal_states.each do |state|
            states[state] = new_state
          end
        end

        lr_pda.states.each do |state|
          new_state = states[state]
          state.transitions.each do |e, other|
            new_state.transitions[e] = states[other]
          end
        end

        return lalr_pda
      end

      def create_lr_pda(start)
        pda = Pda.new @items
        first_sets = compute_first
        # Set of items starting with the start nonterminal
        start_items = @items.select(&.head.==(start)).map do |it|
            LookaheadItem.new it, Set { Terminal.new(Terminal::SPECIAL_EOF) }
        end.to_set
        # Set of all current dotted items
        all_start_items = all_dots(first_sets,  start_items)
        start_state = pda.state_for data: all_start_items

        queue = Set(PState).new
        finished = Set(PState).new

        queue << start_state

        while !queue.empty?
          state = queue.first
          queue.delete state
          next if finished.includes? state

          finished << state
          transitions = get_transitions(state.data)
          transitions.each do |transition, items|
            items = all_dots(first_sets, items)
            new_state = pda.state_for data: items
            state.transitions[transition] = new_state
            queue << new_state
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
