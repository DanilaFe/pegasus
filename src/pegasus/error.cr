require "colorize"

module Pegasus
  module Error
    abstract class PegasusException < Exception
      def initialize(@description : String, @internal = false)
        super()
      end

      def print(io)
        io << "an error".colorize.red.bold
        io << " has occured while "
        io << get_location_name.colorize.bold
        io << ": "
        io << @description
        io.puts

        print_extra(io)

        if @internal
          io << "This error is " << "internal".colorize.bold << ": this means it is likely " << "not your fault".colorize.bold
          io.puts
          io.puts "Please report this error to the developer."
        end
      end

      abstract def get_location_name
      def print_extra(io) end
    end

    class GrammarException < PegasusException
      def get_location_name
        "parsing the grammar definition"
      end
    end

    class NfaException < PegasusException
      def get_location_name
        "compiling regular expressions"
      end
    end

    class DfaException < PegasusException
      def get_location_name
        "creating a deterministic finite automaton"
      end
    end

    class PdaException < PegasusException
      def get_location_name
        "converting grammar rules into a state machine"
      end
    end

    class TableException < PegasusException
      def get_location_name
        "creating lookup tables"
      end
    end
  end

end

macro define_raise(name, class_name)
  def raise_{{name}}(message, internal = false)
    raise Pegasus::Error::{{class_name}}.new message, internal: internal
  end
end

define_raise(grammar, GrammarException)
define_raise(nfa, NfaException)
define_raise(dfa, DfaException)
define_raise(pda, PdaException)
define_raise(table, TableException)
