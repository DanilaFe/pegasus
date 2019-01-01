require "./spec_utils.cr"

describe Pegasus::Dfa do
  describe "#final_table" do
    it "Creates a two-entry table when there are no expression" do
      nfa = Pegasus::Nfa::Nfa.new
      dfa = nfa.dfa
      table = dfa.final_table
      table.size.should eq 2
      table[0].should eq 0
      table[1].should eq 0
    end

    it "Creates a two-entry table with a final state for an empty expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "", 0_i64
      dfa = nfa.dfa
      table = dfa.final_table
      table.size.should eq 2
      table[0].should eq 0
      table[1].should eq 1
    end

    it "Creates two final states for an OR expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h|g", 0_i64
      dfa = nfa.dfa
      table = dfa.final_table
      table.size.should eq 4
      table[0].should eq 0
      table[1].should eq 0
      table[2].should_not eq 0
      table[3].should_not eq 0
    end
  end

  describe "#state_table" do
    it "Does not allow transitions out of the error state" do
      nfa = Pegasus::Nfa::Nfa.new
      dfa = nfa.dfa
      table = dfa.state_table
      table[0].each &.should eq 0
    end

    it "Creates a table leading to the error state when there are no expressions" do
      nfa = Pegasus::Nfa::Nfa.new
      dfa = nfa.dfa
      table = dfa.state_table
      table.each &.each &.should eq 0
    end

    it "Creates a transition table with a final state for a single character" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h", 0_i64
      dfa = nfa.dfa
      table = dfa.state_table
      table.size.should eq 3
      final_byte = 'h'.bytes.first
      table[1].each_with_index do |state, index|
        state.should eq 0 if index != final_byte
        state.should eq 2 if index == final_byte
      end
      table[2].each &.should eq 0
    end

    it "Creates a forked transition table for a fork in the DFA" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h|e", 0_i64
      dfa = nfa.dfa
      table = dfa.state_table
      table.size.should eq 4
      h_byte = 'h'.bytes.first
      e_byte = 'e'.bytes.first
      table[1].each_with_index do |state, index|
        state.should eq 0 if index != h_byte && index != e_byte
        state.should_not eq 0 if index == h_byte || index == e_byte
      end
      table[2].each &.should eq 0
      table[3].each &.should eq 0
    end
  end
end
