require "./spec_helper"

def nonterminal(id)
  Pegasus::Pda::Nonterminal.new id.to_i64
end

def terminal(id)
  Pegasus::Pda::Terminal.new id.to_i64
end

def body(*elements)
  array = [] of Pegasus::Pda::Element
  array.concat elements.to_a
  return array
end

def item(head, body)
  Pegasus::Pda::Item.new head, body
end

class Pegasus::State(V, T)
  def pattern_id
    @data.compact_map(&.data).max_of?(&.+(1)) || 0_i64
  end
end

describe Pegasus::Automaton do
  describe "#initialize" do
    it "Starts at state 0" do
      automaton = Pegasus::Automaton(Int32, Int32).new
      automaton.last_id.should eq 0
    end

    it "Doesn't add any states" do
      automaton = Pegasus::Automaton(Int32, Int32).new
      automaton.states.size.should eq 0
    end

    it "Starts with a nil start state" do
      automaton = Pegasus::Automaton(Int32, Int32).new
      automaton.start.should be_nil
    end
  end

  describe "#state_for" do
    it "Increments the state ID after every created state" do
      automaton = Pegasus::Automaton(Int32, Int32).new
      automaton.state_for(data: 3).id.should eq 0
      automaton.state_for(data: 3).id.should eq 1
      automaton.state_for(data: 4).id.should eq 2
    end

    it "Creates a state with the correct data" do
      automaton = Pegasus::Automaton(Int32, Int32).new
      automaton.state_for(data: 3).data.should eq 3
      automaton.state_for(data: 3).data.should eq 3
      automaton.state_for(data: 4).data.should eq 4
    end

    it "Adds the state to its internal list" do
      automaton = Pegasus::Automaton(Int32, Int32).new
      state_one = automaton.state_for(data: 1)
      state_two = automaton.state_for(data: 2)
      state_three = automaton.state_for(data: 3)

      automaton.states.should contain state_one
      automaton.states.should contain state_two
      automaton.states.should contain state_three
    end
  end
end

describe Pegasus::UniqueAutomaton do
  describe "#initialize" do
    it "Has no state memorized" do
      automaton = Pegasus::UniqueAutomaton(Int32, Int32).new
      automaton.@memorized.size.should eq 0
    end
  end

  describe "#state_for" do
    it "Doesn't create states with duplicate values" do
      automaton = Pegasus::UniqueAutomaton(Int32, Int32).new
      automaton.state_for(data: 3).id.should eq 0
      automaton.state_for(data: 3).id.should eq 0
      automaton.state_for(data: 4).id.should eq 1
    end
  end
end

describe Pegasus::Pda::Terminal do
  describe "#==" do
    it "Compares equivalent terminals correctly" do
      terminal_one = Pegasus::Pda::Terminal.new(0_i64)
      terminal_two = Pegasus::Pda::Terminal.new(0_i64)
      terminal_one.should eq terminal_two
    end

    it "Compares different terminals correctly" do
      terminal_one = Pegasus::Pda::Terminal.new(0_i64)
      terminal_two = Pegasus::Pda::Terminal.new(1_i64)
      terminal_one.should_not eq terminal_two
    end
  end
end

describe Pegasus::Pda::Nonterminal do
  describe "#==" do
    it "Compares equivalent nonterminals correctly" do
      nonterminal_one = Pegasus::Pda::Nonterminal.new(0_i64)
      nonterminal_two = Pegasus::Pda::Nonterminal.new(0_i64)
      nonterminal_one.should eq nonterminal_two
    end

    it "Compares different nonterminals correctly" do
      nonterminal_one = Pegasus::Pda::Nonterminal.new(0_i64)
      nonterminal_two = Pegasus::Pda::Nonterminal.new(1_i64)
      nonterminal_one.should_not eq nonterminal_two
    end
  end
end

describe Pegasus::Pda::Grammar do
  describe "#initialize" do
    it "Doesn't add any items" do
      grammar = Pegasus::Pda::Grammar.new [] of Pegasus::Pda::Terminal,
        [] of Pegasus::Pda::Nonterminal
      grammar.@items.size.should eq 0
    end
  end

  describe "#create_lr_pda" do
    it "Handles empty grammars" do
      grammar = Pegasus::Pda::Grammar.new [] of Pegasus::Pda::Terminal,
        [] of Pegasus::Pda::Nonterminal
      pda = grammar.create_lr_pda nonterminal 0
      pda.states.size.should eq 1
      pda.states.first.transitions.size.should eq 0
      pda.states.first.data.size.should eq 0
    end

    it "Handles grammars with one rule" do
      grammar = Pegasus::Pda::Grammar.new [ terminal 0 ],
        [ nonterminal 0 ]
      grammar.add_item item head: nonterminal(0),
        body: body terminal(0)
      pda = grammar.create_lr_pda nonterminal 0
      pda.states.size.should eq 2 # Start + with item shifted over

      start_state = pda.states.find(&.id.==(0)).not_nil!
      start_state.transitions.size.should eq 1 # To the shifted state
      start_state.data.size.should eq 1 # The one initial item
    end

    it "Handles grammars with epsilon-moves" do
      terminals = [ terminal 0 ]
      nonterminals = [ nonterminal(0), nonterminal(1) ]

      grammar = Pegasus::Pda::Grammar.new terminals, nonterminals
      grammar.add_item item head: nonterminals[0],
        body: body nonterminals[1]
      grammar.add_item item head: nonterminals[1],
        body: body terminals[0]

      pda = grammar.create_lr_pda nonterminals[0]
      pda.states.size.should eq 3

      start_state = pda.states.find(&.id.==(0))
      start_state.should_not be_nil
      start_state = start_state.not_nil!
      start_state.transitions.size.should eq 2
      start_state.data.size.should eq 2

      reduce_terminal_state = start_state.transitions[terminals[0]]?
      reduce_terminal_state.should_not be_nil
      reduce_terminal_state = reduce_terminal_state.not_nil!
      reduce_terminal_state.data.size.should eq 1
      reduce_terminal_state.data.first.index.should eq 1
      reduce_terminal_state.data.first.item.head.should eq nonterminals[1]
      reduce_terminal_state.data.first.item.body[0].should eq terminals[0]

      reduce_terminal_state = start_state.transitions[nonterminals[1]]?
      reduce_terminal_state.should_not be_nil
      reduce_terminal_state = reduce_terminal_state.not_nil!
      reduce_terminal_state.data.size.should eq 1
      reduce_terminal_state.data.first.index.should eq 1
      reduce_terminal_state.data.first.item.head.should eq nonterminals[0]
      reduce_terminal_state.data.first.item.body[0].should eq nonterminals[1]
    end
  end

  describe "#create_lalr_pda" do
    it "Meges states with duplicate bodies" do
      # This grammar is taken from grammars/modern_compiler_design.grammar
      t_x = terminal(0)
      t_b = terminal(1)
      t_a = terminal(2)
      terminals = [ t_x, t_b, t_a ]

      s = nonterminal 0
      a = nonterminal 1
      b = nonterminal 2
      nonterminals = [ s, a, b ]

      grammar = Pegasus::Pda::Grammar.new terminals, nonterminals
      grammar.add_item item head: s,
        body: body a
      grammar.add_item item head: s,
        body: body t_x, t_b
      grammar.add_item item head: a,
        body: body t_a, a, t_b
      grammar.add_item item head: a,
        body: body b
      grammar.add_item item head: b,
        body: body t_x
    
      lr_pda = grammar.create_lr_pda s
      lalr_pda = grammar.create_lalr_pda lr_pda
      lr_pda.states.size.should eq 13
      lalr_pda.states.size.should eq 9
    end
  end
end

describe Pegasus::Pda::DottedItem do
  describe "#next_item!" do
    it "Advances the index when possible" do
      new_item = item head: nonterminal(0),
        body: body terminal(0), terminal(0)
      dotted_item = Pegasus::Pda::DottedItem.new new_item, index: 0_i64
      dotted_item.next_item!
      dotted_item.index.should eq 1
      dotted_item.next_item!
      dotted_item.index.should eq 2
    end

    it "Raises when already at the end" do
      new_item = item head: nonterminal(0),
        body: body terminal(0), terminal(0)
      dotted_item = Pegasus::Pda::DottedItem.new new_item, index: 2_i64
      expect_raises(Exception) do
        dotted_item.next_item!
      end
    end
  end

  describe "#done?" do
    it "Returns false when dot is not past the last element" do
      new_item = item head: nonterminal(0),
        body: body terminal(0), terminal(0)
      dotted_item = Pegasus::Pda::DottedItem.new new_item, index: 0_i64
      dotted_item.done?.should be_false
    end

    it "Returns true when dot is just after the last element" do
      new_item = item head: nonterminal(0),
        body: body terminal(0), terminal(0)
      dotted_item = Pegasus::Pda::DottedItem.new new_item, index: 2_i64
      dotted_item.done?.should be_true
    end
  end
end

describe Pegasus::Nfa::Nfa do
  describe "#initialize" do
    it "Creates a start state" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.@start.should_not be_nil
    end

    it "Doesn't create a final start state" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.@start.try(&.data).should be_nil
    end
  end

  describe "#dfa" do
    it "Creates an empty DFA with no final states when no patterns were added" do
      nfa = Pegasus::Nfa::Nfa.new
      dfa = nfa.dfa
      dfa.states.size.should eq 1
      dfa.states.each do |state|
        state.data.each do |nfa_state|
          nfa_state.data.should be_nil
        end
      end
    end

    it "Sets the start state of the new DFA" do
      nfa = Pegasus::Nfa::Nfa.new
      dfa = nfa.dfa
      dfa.start.should_not be_nil
      dfa.start.try(&.id).should eq 0_i64
    end

    it "Creates a basic two-state DFA for single-character patterns" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h", 0_i64
      dfa = nfa.dfa

      dfa.states.size.should eq 2
      dfa.states.each do |state|
        if state == dfa.start
          state.data.each &.data.should be_nil
          state.transitions.size.should eq 1
          next_state = state.transitions['h'.bytes.first]?
          next_state.should_not be_nil
        else
          state.pattern_id.should eq 1
        end
      end
    end
    
    it "Creates a DFA for an OR expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h|e", 0_i64
      dfa = nfa.dfa
      dfa.states.size.should eq 3
      dfa.states.each do |state|
        if state == dfa.start
          state.data.each &.data.should be_nil
          state.transitions.size.should eq 2
          h_state = state.transitions['h'.bytes.first]?
          h_state.should_not be_nil
          e_state = state.transitions['e'.bytes.first]?
          e_state.should_not be_nil
        else
          state.pattern_id.should eq 1
        end
      end
    end

    it "Creates a DFA for a + expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h+", 0_i64
      dfa = nfa.dfa
      dfa.states.size.should eq 2
      dfa.states.each do |state|
        if state == dfa.start
          state.data.each &.data.should be_nil
          state.transitions.size.should eq 1
          h_state = state.transitions['h'.bytes.first]?
          h_state.should_not be_nil
        else
          state.pattern_id.should eq 1
          state.transitions.size.should eq 1
          state.transitions['h'.bytes.first]?.should eq state
        end
      end
    end

    it "Creates a DFA for a * expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h*", 0_i64
      dfa = nfa.dfa
      dfa.states.size.should eq 2
      dfa.states.each do |state|
        state.pattern_id.should eq 1
        state.transitions.size.should eq 1
      end
    end

    it "Creates a DFA for a ? expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h?", 0_i64
      dfa = nfa.dfa
      dfa.states.size.should eq 2
      dfa.states.each do |state|
        state.pattern_id.should eq 1
        if state == dfa.start
          next_state = state.transitions['h'.bytes.first]?
          next_state.should_not be_nil
        else
          state.transitions['h'.bytes.first]?.should be_nil
        end
      end
    end
  end
end

describe Pegasus::Nfa::Transition do
  describe "#char_states" do
    it "Does not return any states" do
      transition = Pegasus::Nfa::Transition.new
      transition.char_states.size.should eq 0
    end
  end
end

describe Pegasus::Nfa::ByteTransition do
  describe "#char_states" do
    it "Only returns one byte" do
      transition = Pegasus::Nfa::ByteTransition.new 0_u8
      transition.char_states.should eq [ 0_u8 ]
    end
  end
end

describe Pegasus::Nfa::AnyTransition do
  describe "#char_states" do
    it "Returns the full unsigned byte range" do
      transition = Pegasus::Nfa::AnyTransition.new
      transition.char_states.should eq (0_u8..255_u8).to_a
    end
  end
end

describe Pegasus::Nfa::RangeTransition do
  describe "#char_states" do
    it "Returns the given ranges when not inverted" do
      transition = Pegasus::Nfa::RangeTransition.new ranges: [(0_u8..1_u8), (2_u8..3_u8)],
        inverted: false
      transition.char_states.sort.should eq [ 0_u8, 1_u8, 2_u8, 3_u8 ]
    end

    it "Returns the ranges not given when inverted" do
      transition = Pegasus::Nfa::RangeTransition.new ranges: [(0_u8..127_u8), (130_u8..255_u8)],
        inverted: true
      transition.char_states.sort.should eq [ 128_u8, 129_u8 ]
    end
  end
end
