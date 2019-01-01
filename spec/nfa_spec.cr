require "./spec_utils.cr"

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

    it "Does not create negative states" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "hello", 0_i64
      nfa.add_regex "goodbye", 1_i64
      dfa = nfa.dfa
      dfa.states.each do |state|
        state.id.should be >= 0
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

    it "Creates a DFA for a range expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "[helo0-9]", 0_i64
      dfa = nfa.dfa
      dfa.states.size.should eq 2
      dfa.states.each do |state|
        if state == dfa.start
          state.transitions.size.should eq 14
        else
          state.transitions.size.should eq 0
          state.pattern_id.should eq 1
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

describe Pegasus::Nfa::StateChain do
  describe "#initialize" do
    it "Sets the final state to the start state if no final state is given" do
      state = Pegasus::Nfa::NState.new id: 0_i64, data: nil
      chain = Pegasus::Nfa::StateChain.new start: state
      chain.start.should eq state
      chain.final.should eq state
    end

    it "Adds a transition to its tail state when concatenated with another chain" do
      state_one = Pegasus::Nfa::NState.new id: 0i64, data: nil
      state_two = Pegasus::Nfa::NState.new id: 1i64, data: nil
      first_chain = Pegasus::Nfa::StateChain.new state_one, state_one
      second_chain = Pegasus::Nfa::StateChain.new state_two, state_two
      first_chain.append! second_chain
      first_chain.start.should eq state_one
      first_chain.final.should eq state_two
      first_chain.start.transitions.size.should eq 1
      first_chain.start.transitions.keys[0].should be_a Pegasus::Nfa::LambdaTransition
      first_chain.start.transitions.values[0].should be state_two
    end

    it "Doesn't do anything when a Nil is appended" do
      state_one = Pegasus::Nfa::NState.new id: 0i64, data: nil
      state_two = Pegasus::Nfa::NState.new id: 1i64, data: nil
      state_one.transitions[Pegasus::Nfa::LambdaTransition.new] = state_two
      first_chain = Pegasus::Nfa::StateChain.new state_one, state_two
      first_chain.append! nil
      first_chain.start.should eq state_one
      first_chain.final.should eq state_two
      first_chain.final.transitions.size.should eq 0
    end
  end
end

describe Pegasus::Nfa::Nfa do
  describe "#add_regex" do
    it "Correctly compiles one-character regular expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h", 0_i64
      (nfa.start.try(&.transitions.size) || 0).should eq 1
      nfa.states.size.should eq 4
    end

    it "Does not add negative states" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "hello", 0_i64
      nfa.states.each do |state|
        state.id.should be >= 0
      end
    end

    it "Correctly compiles OR regular expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h|e", 0_i64
      nfa.start.not_nil!.transitions.size.should eq 1
      nfa.states.size.should eq 8
      or_branch_state = nfa.start.not_nil!.transitions.values[0]
      or_branch_state.transitions.size.should eq 2
      seen_h = false
      seen_e = false
      or_branch_state.transitions.map(&.[1]).each do |state|
        transition_byte = state.transitions.keys[0].as?(Pegasus::Nfa::ByteTransition).try(&.byte)
        seen_h |= transition_byte == 'h'.bytes.first
        seen_e |= transition_byte == 'e'.bytes.first
      end
      seen_h.should be_true
      seen_e.should be_true
    end

    it "Correctly compiles ? regular expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h?", 0_i64
      nfa.start.not_nil!.transitions.size.should eq 1
      nfa.states.size.should eq 6
      skip_from = nfa.start.not_nil!.straight_path(length: 1)
      skip_from.should_not be_nil
      skip_from = skip_from.not_nil!
      skip_from.transitions.size.should eq 2
    end

    it "Correctly compiles * regular expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h?", 0_i64
      nfa.start.not_nil!.transitions.size.should eq 1
      nfa.states.size.should eq 6
      skip_from = nfa.start.not_nil!.straight_path(length: 1)
      skip_from.should_not be_nil
      skip_from = skip_from.not_nil!
      skip_from.transitions.size.should eq 2
    end

    it "Correctly compiles + regular expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h+", 0_i64
      nfa.start.not_nil!.transitions.size.should eq 1
      nfa.states.size.should eq 6
      return_to = nfa.start.not_nil!.straight_path(length: 1)
      return_to.should_not be_nil
      return_to = return_to.not_nil!
      return_to.transitions.size.should eq 1

      return_from = return_to.straight_path(length: 3)
      return_from.should_not be_nil
      return_from = return_from.not_nil!
      return_from.transitions.size.should eq 2
    end

    it "Correctly compiles range expression" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "[helo0-9]", 0_i64
      nfa.states.size.should eq 4
      contained = { 'h' => false, 'o' => false, '1' => false, '9' => false }
      range_transition_state = nfa.start.not_nil!.straight_path(length: 1)
      range_transition_state.should_not be_nil
      range_transition_state = range_transition_state.not_nil!
      range_transition_state.transitions.each do |transition, _|
        contained.each do |k, _|
          byte = k.bytes[0]
          if transition.as?(Pegasus::Nfa::RangeTransition).try &.ranges.one? &.includes? byte
            contained[k] = true
          end
        end
      end
      contained.values.all_should eq true
    end

    it "Does not compile incomplete escape codes" do
      nfa = Pegasus::Nfa::Nfa.new
      expect_raises(Pegasus::Error::NfaException) do
        nfa.add_regex "h\\", 1_i64
      end
    end

    it "Does not compile invalid escape codes" do
      nfa = Pegasus::Nfa::Nfa.new
      expect_raises(Pegasus::Error::NfaException) do
        nfa.add_regex "\\h", 1_i64
      end
    end

    it "Correctly compiles valid escape codes" do
      nfa = Pegasus::Nfa::Nfa.new
      specials = [ "\\\"", "\\'", "\\[", "\\]", "\\(", "\\)", "\\|",  "\\?", "\\*", "\\+", "\\.", "\\n" ]

      specials.each_with_index do |special, index|
        nfa.add_regex special, index.to_i64
      end

      nfa.start.not_nil!.transitions.size.should eq specials.size
      transition_bytes = [] of UInt8
      nfa.start.not_nil!.transitions.values.each do |state|
        state.transitions.size.should eq 1
        state.transitions.keys[0].should be_a(Pegasus::Nfa::ByteTransition)
        transition_bytes << state.transitions.keys[0].as(Pegasus::Nfa::ByteTransition).byte
      end
      transition_bytes[0...transition_bytes.size - 1].should eq specials[0...specials.size - 1].map(&.[1].bytes.[0])
      transition_bytes.last.should eq '\n'.bytes[0]
    end

    it "Combines several regular expressions" do
      nfa = Pegasus::Nfa::Nfa.new
      nfa.add_regex "h", 1_i64
      nfa.add_regex "e", 2_i64
      nfa.start.not_nil!.transitions.size.should eq 2
    end

    it "Does not compile invalid operators" do
      nfa = Pegasus::Nfa::Nfa.new
      expect_raises(Pegasus::Error::NfaException) do
        nfa.add_regex "+", 0_i64
      end

      expect_raises(Pegasus::Error::NfaException) do
        nfa.add_regex "h(+)", 0_i64
      end
    end

    it "Does not compile mismatched parentheses" do
      nfa = Pegasus::Nfa::Nfa.new
      expect_raises(Pegasus::Error::NfaException) do
        nfa.add_regex "(", 0_i64
      end

      expect_raises(Pegasus::Error::NfaException) do
        nfa.add_regex ")", 0_i64
      end
    end
  end
end
