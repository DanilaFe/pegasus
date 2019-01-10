require "colorize"

module Pegasus
  module Error
    abstract class ErrorContext
      abstract def to_s(io)
    end

    abstract class PegasusException < Exception
      getter context_data : Array(ErrorContext)

      def initialize(@description : String, @context_data = [] of ErrorContext, @internal = false)
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

      def print_extra(io)
        @context_data.each do |data|
          io << " - " << data
          io.puts
        end
      end

      abstract def get_location_name
    end

    class GeneralException < PegasusException
      def get_location_name
        "converting grammar to a parser description"
      end
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
  def raise_{{name}}(message, context_data = [] of Pegasus::Error::ErrorContext, internal = false)
    raise Pegasus::Error::{{class_name}}.new message,
      context_data: context_data.map(&.as(Pegasus::Error::ErrorContext)),
      internal: internal
  end
end

define_raise(general, GeneralException)
define_raise(grammar, GrammarException)
define_raise(nfa, NfaException)
define_raise(dfa, DfaException)
define_raise(pda, PdaException)
define_raise(table, TableException)
