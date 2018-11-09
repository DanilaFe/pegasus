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
