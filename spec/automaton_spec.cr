require "./spec_utils.cr"

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
