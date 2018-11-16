require "./spec_utils.cr"

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

describe Pegasus::Pda::Pda do
  describe "#action_table" do
    it "Creates no actions for the error state" do
      new_pda = pda item head: nonterminal(0), body: body terminal(0)
      new_table = new_pda.action_table
      new_table[0].each &.should eq -1
    end

    it "Creates a shift and a reduce action for a single nonterminal to terminal item" do
      new_pda = pda item head: nonterminal(0), body: body terminal(0)
      new_table = new_pda.action_table
      new_table[1][1].should eq 0
      new_table[1][0].should eq -1
      new_table[2][0].should eq 1
      new_table[2][1].should eq -1
    end

    it "Creates two shift and two reduce actions for a start state with two productions" do
      new_pda = pda item(head: nonterminal(0), body: body terminal(0)),
        item(head: nonterminal(0), body: body terminal(1))
      new_table = new_pda.action_table
      new_table[1][0].should eq -1
      new_table[1][1].should eq 0
      new_table[1][2].should eq 0
      new_table[2][0].should eq 1
      new_table[2][1].should eq -1
      new_table[2][2].should eq -1
      new_table[3][0].should eq 2
      new_table[3][1].should eq -1
      new_table[3][2].should eq -1
    end

    it "Correctly reports a reduce reduce conflict" do
      new_pda = pda item(head: nonterminal(0), body: body nonterminal(1)),
        item(head: nonterminal(0), body: body nonterminal(2)),
        item(head: nonterminal(1), body: body terminal(0)),
        item(head: nonterminal(2), body: body terminal(0))
      expect_raises(Exception) do
        new_table = new_pda.action_table
      end
    end

    it "Correctly reports a shift/reduce conflict" do
      new_pda = pda item(head: nonterminal(0), body: body nonterminal(1), terminal(1)),
        item(head: nonterminal(0), body: body nonterminal(2)),
        item(head: nonterminal(1), body: body terminal(0)),
        item(head: nonterminal(2), body: body terminal(0), terminal(1))
      expect_raises(Exception) do
        new_table = new_pda.action_table
      end
    end
  end
  
  describe "#state_table" do
    it "Does not allow transitions out of the error state" do
      new_pda = pda item head: nonterminal(0), body: body terminal(0)
      new_table = new_pda.state_table
      new_table[0].each &.should eq 0
    end

    it "Creates transitions for terminals" do
      new_pda = pda item head: nonterminal(0), body: body terminal(0)
      new_table = new_pda.state_table
      new_table[1][0].should eq 0
      new_table[1][1].should eq 2
      new_table[1][2].should eq 0
      new_table[2].each &.should eq 0
    end

    it "Creates transitions for nonterminals" do
      new_pda = pda item(head: nonterminal(0), body: body nonterminal(1)),
        item(head: nonterminal(1), body: body terminal(0))
      new_table = new_pda.state_table
      new_table[1][0].should eq 0
      new_table[1][1].should_not eq 0
      new_table[1][2].should eq 0
      new_table[1][3].should_not eq 0
      new_table[1][1].should_not eq new_table[1][3]
      new_table[2].each &.should eq 0
      new_table[3].each &.should eq 0
    end
  
    it "Creates transitions for sequences of elements" do
      new_pda = pda item head: nonterminal(0), body: body terminal(0), terminal(1)
      new_table = new_pda.state_table
      new_table[1].all_should eq(0), except(1, should: eq 2)
      new_table[2].all_should eq(0), except(2, should: eq 3)
      new_table[3].all_should eq(0)
    end
  end
end

