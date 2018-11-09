require "./spec_helper"

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
      pda = grammar.create_lr_pda Pegasus::Pda::Nonterminal.new 0_i64
      pda.states.size.should eq 1
      pda.states.first.transitions.size.should eq 0
      pda.states.first.data.size.should eq 0
    end

    it "Handles grammars with one rule" do
      grammar = Pegasus::Pda::Grammar.new [ Pegasus::Pda::Terminal.new 0_i64 ],
        [ Pegasus::Pda::Nonterminal.new 0_i64 ]
      grammar.add_item Pegasus::Pda::Item.new head: Pegasus::Pda::Nonterminal.new(0_i64),
        body: [ Pegasus::Pda::Terminal.new 0_i64 ] of Pegasus::Pda::Element
      pda = grammar.create_lr_pda Pegasus::Pda::Nonterminal.new 0_i64
      pda.states.size.should eq 2 # Start + with item shifted over

      start_state = pda.states.find(&.id.==(0)).not_nil!
      start_state.transitions.size.should eq 1 # To the shifted state
      start_state.data.size.should eq 1 # The one initial item
    end

    it "Handles grammars with epsilon-moves" do
      terminals = [ Pegasus::Pda::Terminal.new 0_i64 ]
      nonterminals = [ Pegasus::Pda::Nonterminal.new(0_i64),
        Pegasus::Pda::Nonterminal.new(1_i64) ]
      grammar = Pegasus::Pda::Grammar.new terminals, nonterminals
      grammar.add_item Pegasus::Pda::Item.new head: nonterminals[0],
        body: [ nonterminals[1] ] of Pegasus::Pda::Element
      grammar.add_item Pegasus::Pda::Item.new head: nonterminals[1],
        body: [ terminals[0] ] of Pegasus::Pda::Element
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
      t_x = Pegasus::Pda::Terminal.new(0_i64)
      t_b = Pegasus::Pda::Terminal.new(1_i64)
      t_a = Pegasus::Pda::Terminal.new(2_i64)
      terminals = [
        t_x, t_b, t_a
      ]
      s = Pegasus::Pda::Nonterminal.new(0_i64)
      a = Pegasus::Pda::Nonterminal.new(1_i64)
      b = Pegasus::Pda::Nonterminal.new(2_i64)
      nonterminals = [
        s, a, b
      ]

      grammar = Pegasus::Pda::Grammar.new terminals, nonterminals
      grammar.add_item Pegasus::Pda::Item.new head: s,
        body: [ a ] of Pegasus::Pda::Element
      grammar.add_item Pegasus::Pda::Item.new head: s,
        body: [ t_x, t_b ] of Pegasus::Pda::Element
      grammar.add_item Pegasus::Pda::Item.new head: a,
        body: [ t_a, a, t_b ] of Pegasus::Pda::Element
      grammar.add_item Pegasus::Pda::Item.new head: a,
        body: [ b ] of Pegasus::Pda::Element
      grammar.add_item Pegasus::Pda::Item.new head: b,
        body: [ t_x ] of Pegasus::Pda::Element
    
      lr_pda = grammar.create_lr_pda s
      lalr_pda = grammar.create_lalr_pda lr_pda
      lr_pda.states.size.should eq 13
      lalr_pda.states.size.should eq 9
    end
  end
end
