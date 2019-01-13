require "colorize"

module Pegasus
  # This module contains all the error-related code.
  # This includes a custom exception class and context for it.
  module Error
    # A context for the custom exception class.
    # The idea with context is that it can be attached to exceptions and
    # shown as extra information to the user. It's attached rather than
    # added via subclassing because some parts of Pegasus code need to be
    # able to modify the context, replacing it with more thorough / clear
    # info. Instead of straight up copying the exception and changing the field,
    # (as well as the way it's displayed to the user), client code can
    # remove one bit of context and replace it with a better one.
    abstract class ErrorContext
      abstract def to_s(io)
    end

    # An exception thrown by Pegasus. Unlike Crystal exceptions, which will
    # be reported directly to the user without any prettyfication, the Pegasus exception is created to
    # display the error information to the user in a clear and pretty way. This includes coloring and
    # emphasizing certain sections of the message, and generally presenting them in a user-friendly way.
    abstract class PegasusException < Exception
      getter context_data : Array(ErrorContext)

      def initialize(@description : String, @context_data = [] of ErrorContext, @internal = false)
        super()
      end

      # Prints the exception to the given IO.
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

      # Prints the context that the exception has attached.
      def print_extra(io)
        @context_data.each do |data|
          io << " - " << data
          io.puts
        end
      end

      # Get the "location" of the error, which is used to
      # report to the user when in the process the error occured.
      abstract def get_location_name
    end

    # An exception thrown at some point in the entire lifetime of Pegasus.
    # This is very vague, and should be used in cases where it cannot be known
    # what the surrounding code is doing at the time.
    class GeneralException < PegasusException
      def get_location_name
        "converting grammar to a parser description"
      end
    end

    # An exception used to signify that an error occured during grammar parsing.
    class GrammarException < PegasusException
      def get_location_name
        "parsing the grammar definition"
      end
    end

    # An exception used to signify that an error occured while creating
    # Nondeterministic Finite Automata.
    class NfaException < PegasusException
      def get_location_name
        "compiling regular expressions"
      end
    end

    # An exception used to signify that an error occured while creating
    # Deterministic Finite Automata.
    class DfaException < PegasusException
      def get_location_name
        "creating a deterministic finite automaton"
      end
    end

    # An exception used to signify that an error occured while creating
    # Push Down Automata.
    class PdaException < PegasusException
      def get_location_name
        "converting grammar rules into a state machine"
      end
    end

    # An exception used to signify that an error occured while creating
    # the lookup tables necessary for the Pegasus state machine.
    class TableException < PegasusException
      def get_location_name
        "creating lookup tables"
      end
    end
  end

end

# Define a raise function from a name and a Pegasus exception class.
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
