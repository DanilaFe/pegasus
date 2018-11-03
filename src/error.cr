require "colorize"

module Pegasus
  module Error
    # Determines where the error occured in Pegasus execution.
    enum ErrorState
      # Error occured while parsing pegasus file.
      GrammarGen
      # Error occured while converting regular expressions to NFA states.
      NfaGen
      # Error occured while converting an NFA to a DFA.
      DfaGen
      # Error occured while converting grammar items into a PDA.
      PdaGen
      # Error occured while generating lookup table.
      TableGen

      def human_string
        memory = IO::Memory.new
        human_string(memory)
        return memory.to_s
      end

      def human_string(io)
        case self
        when GrammarGen
          io << "parsing the grammar definition"
        when NfaGen
          io << "compiling regular expressions"
        when DfaGen
          io << "creating a deterministic finite automaton"
        when PdaGen
          io << "converting grammar rules into a state machine"
        when TableGen
          io << "creating lookup tables"
        end
      end
    end

    class PegasusError < Exception
      getter state : ErrorState
      getter internal : Bool

      def initialize(@state, @internal = false, @message : String? = nil)
      end

      def to_s(io)
        io << "an error".colorize.red.bold << " has occured while " << @state.human_string.colorize.bold << ":"
        io.puts
        if @message
          io << "  "
          io.puts @message
        end
        if @internal
          io << "This error is " << "internal".colorize.bold << ": this means it is likely " << "not your fault".colorize.bold
          io.puts
          io.puts "Please report this error to the developer."
        end
      end
    end
  end

end

macro define_raise(name, enum_name)
  def raise_{{name}}(message, internal = false)
    raise Pegasus::Error::PegasusError.new Pegasus::Error::ErrorState::{{enum_name}}, internal, message
  end
end

define_raise(grammar, GrammarGen)
define_raise(nfa, NfaGen)
define_raise(dfa, DfaGen)
define_raise(pda, PdaGen)
define_raise(table, TableGen)
