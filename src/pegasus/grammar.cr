require "./elements.cr"
require "./items.cr"
require "./pda.cr"

module Pegasus
  # This module holds code related to push down automata, as well
  # as other helper code such as items (productions, basically),
  # dotted items (productions which know what part of the production
  # has already been parsed) and the like.
  module Pda
    # A Grammar associated with the language, contianing a list of terminals,
    # nonterminals, and the context-free production rules given by the `Item` class.
    class Grammar
      # The items that belong to this grammar.
      getter items : Array(Item)
      # The terminals that belong to this grammar.
      getter terminals : Array(Elements::TerminalId)
      # The nonterminals that belong to this grammar.
      getter nonterminals : Array(Elements::NonterminalId)

      # Initializes this grammar with the given terminals and nonterminals.
      def initialize(@terminals, @nonterminals)
        @items = Array(Item).new
      end

      # Checks if the given set contains the empty set. This is used for computing
      # FIRST and lookahead sets when generating an (LA)LR automaton.
      private def contains_empty(set)
        return set.select(&.is_a?(Elements::EmptyElement)).size != 0
      end

      # Concatenates a set with another set, and returns whether the size of the set
      # has changed. This is useful for "closure algorithms" as described by
      # Dick Grune and others in Modern Compiler Design. These algorithms apply
      # a rule until the data no longer changes.
      private def concat_watching(set, other)
        initial_size = set.size
        set.concat other
        return initial_size != set.size
      end

      # Computes the FIRST set of an alternative. The first sets hash is used
      # for already computed first sets. The empty alternative is added elsewhere,
      # and only contains the SPECIAL_EMPTY terminal.
      private def compute_alternative_first(first_sets, alternative)
        if !first_sets.has_key? alternative
          first = Set(Elements::LookaheadElement).new
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
            add_first = add_first.reject &.is_a?(Elements::EmptyElement)
        end

        return concat_watching(first, add_first)
      end

      # Computes the first set of every alternative or alternative tail of the given
      # item body.
      private def compute_alternatives_first(first_sets, body)
        change_occured = false
        body.size.times do |time|
          change_occured |= compute_alternative_first(first_sets, body[time...body.size])
        end
        return change_occured
      end

      # Computes the first sets of all the terminals, nonterminals, alternatives,
      # and alternative tails by examining the items, terminals, and nonterminals given
      # in `#initialize`
      private def compute_first
        first_sets = Hash(Elements::NonterminalId | Elements::TerminalId | Array(Elements::NonterminalId | Elements::TerminalId), Set(Elements::LookaheadElement)).new
        @terminals.each { |t| first_sets[t] = Set(Elements::LookaheadElement) { t } }
        @nonterminals.each { |nt| first_sets[nt] = Set(Elements::LookaheadElement).new }
        first_sets[[] of Elements::NonterminalId | Elements::TerminalId] = Set(Elements::LookaheadElement) { Elements::EmptyElement.new }
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

      # Gets a lookahead set for the given alternative, using its parent lookahead set.
      private def get_lookahead(first_sets, alternative, old_lookahead)
        lookahead = first_sets[alternative].dup
        if contains_empty(lookahead)
          lookahead.concat(old_lookahead)
          lookahead = lookahead.reject &.is_a?(Elements::EmptyElement)
        end
        return lookahead.to_set
      end

      # Creates new dotted items that are to be added because the "dot" is on the left on a nonterminal
      # in the parent dotted item. The suffix parameter describes all the tokens after the nonterminal,
      # which is used for looking up in the FIRST set.
      private def create_dotted_items(first_sets, nonterminal, suffix, parent_lookahead)
          return @items.select(&.head.==(nonterminal))
                      .map { |it| LookaheadItem.new it, get_lookahead(first_sets, suffix, parent_lookahead) }
      end

      # Creates new dotted items for every existing dotted item. This may be necessary if the "dot" moved
      # and is now on the left hand of a Elements::NonterminalId, which warrants all the production rules for that nonterminal
      # To be added to the current set (with their lookahead sets computed from scratch).
      private def new_dots(first_sets, dots)
        dots.map do |dot|
          next Set(LookaheadItem).new if dot.index >= dot.item.body.size
          next Set(LookaheadItem).new if dot.item.body[dot.index].is_a?(Elements::LookaheadElement)
          next create_dotted_items(first_sets, dot.item.body[dot.index], dot.item.body[(dot.index+1)...dot.item.body.size], dot.lookahead)
        end.reduce(Set(LookaheadItem).new) do |set, list|
          set.concat list
        end
      end

      # Creates all dotted items from the given list of "initial" dotted items.
      private def all_dots(first_sets, dots)
        found_dots = dots.to_set.dup
        while concat_watching(found_dots, new_dots(first_sets, found_dots))
        end
        groups = found_dots.group_by { |dot| { dot.item, dot.index } }
        found_dots = groups.map do |k, v|
          item, index = k
          merged_lookahead = v.map(&.lookahead).reduce(Set(Elements::LookaheadElement).new) { |l, r| l.concat r }
          LookaheadItem.new item, merged_lookahead, index
        end
        return found_dots.to_set
      end

      # Gets a set of shifted items for each possible shift-transition
      # from the current state.
      private def get_transitions(dotted_items)
        return dotted_items.compact_map do |dot|
            next nil unless dot.index < dot.item.body.size
            next { dot.item.body[dot.index], dot.next_item }
        end.reduce(Hash(Elements::NonterminalId | Elements::TerminalId, Set(LookaheadItem)).new) do |hash, kv|
           k, v = kv
           hash[k] = hash[k]?.try(&.<<(v)) || Set { v }
           next hash
        end
      end

      # Converts an LR(1) PDA to an LALR(1) PDA by merging states with the corresponding bodies, and
      # combining the lookahead sets of every matching item.
      def create_lalr_pda(lr_pda)
        lalr_pda = Pda.new @items
        groups = lr_pda.states.group_by { |s| s.data.map { |it| DottedItem.new it.item, it.index }.to_set }
        # Since 2+ sets become one, we need to adjust transitions.
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

        # Reconnect the new states.
        lr_pda.states.each do |state|
          new_state = states[state]
          state.transitions.each do |e, other|
            new_state.transitions[e] = states[other]
          end
        end

        return lalr_pda
      end

      # Create an LR(1) PDA given a start symbol.
      def create_lr_pda
        pda = Pda.new @items
        first_sets = compute_first
        # Set of items starting with the start nonterminal
        start_items = @items.select(&.head.start?).map do |it|
          LookaheadItem.new it, Set(Elements::LookaheadElement) { Elements::EofElement.new }
        end
        # Set of all current dotted items
        all_start_items = all_dots(first_sets, start_items)
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

      # Add an item to the Grammar.
      def add_item(i)
        items << i
      end
    end
  end
end
