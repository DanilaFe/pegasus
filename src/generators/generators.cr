require "../pegasus/language_def.cr"
require "option_parser"

module Pegasus::Generators::Api
  # Class that specifies the program's output mode.
  # The idea is to generalize behaviors such as
  # merging into a single file or printing out to STDOUT.
  # The `#output` method takes in a parser and, as side effect,
  # should emit the output of its various `FileGenerator` classes.
  abstract class OutputMode
    # Output the content of the given `opt_parser`.
    abstract def output(opt_parser)
  end

  # Output mode that produces individual files
  # as specified by the `FileGenerator` classes.
  class FilesOutputMode < OutputMode
    def output(opt_parser)
      opt_parser.file_gens.each do |gen|
        file = File.open(opt_parser.output_file_names[gen.name], "w")
        gen.to_s(file)
        file.close
      end
    end
  end

  # Output mode that produces a single file.
  class FileOutputMode < OutputMode
    # Creates a new file output mode that generates a file with the given name.
    def initialize(@filename : String)
    end

    def output(opt_parser)
      file = File.open(@filename, "w")
      opt_parser.file_gens.each do |gen|
        gen.to_s(file)
      end
      file.close
    end
  end

  # Output mode that prints all the generated files to STDOUT,
  # in the order they were added to the `PegasusOptionParser`
  class StdOutputMode < OutputMode
    def output(opt_parser)
      opt_parser.file_gens.each do |gen|
        gen.to_s(STDOUT)
      end
    end
  end

  # A generalization of data input. Subclasses
  # such as `StdInput` and `FileInput` provide
  # a way to read grammar / semantics files from
  # various sources. The `#add_option` method registers
  # command-line option(s) for the user to configure.
  abstract class Input(I)
    # Register this input method's options
    # with the given `PegasusOptionParser`.
    def add_option(opt_parser)
    end

    # Read input of type `I`.
    abstract def process(opt_parser) : I
  end

  # Input method that reads directly from `STDIN`.
  # This technically doesn't add any new methods,
  # but makes code more clear.
  abstract class StdInput(I) < Input(I)
  end

  # Input method that reads from a file, the
  # name of which is specified on the command line.
  abstract class FileInput(I) < Input(I)
    # The internal name of this input. The `PegasusOptionParser`
    # will associated a file name with this string.
    property name : String
    # The user-friendly description of the input
    # that will be shown on the help screen.
    property description : String
    # The name of the file to read from.
    property filename : String?

    # Create a new file input with the given internal name
    # and user-friendly description.
    def initialize(@name, @description)
    end

    def process(opt_parser) : I
      file = File.open(@filename.not_nil!, "r")
      result = process(opt_parser, file)
      file.close
      return result
    end

    def add_option(opt_parser)
      opt_parser.option_parser.on("-#{name[0].downcase} FILE",
                                  "--input-#{name}=FILE",
                                  "Sets #{description}") do |file|
        @filename = file
      end
    end

    # Read a value of type `I` from a file.
    abstract def process(opt_parser, file) : I
  end
  
  # High-level class for constructing parser generators
  # that are configurable from the command line.
  # 
  # This class uses `Input` to read a value of
  # type `I`, then uses the registered `FileGenerator` instances
  # to produce output via an `OutputMode`. All of these
  # listed classes are registered with Crystal's native `OptionParser`,
  # which serves to provide a user with configuration options.
  # 
  # The `#output_file_names` and `#input_file_names` hashes store
  # the names of target output files and input files, respectively.
  # These are updated by the `Input` and `FileGenerator`s, as well
  # as through user-supplied command-line options.
  class PegasusOptionParser(C, I)
    # The context class (which must implement the `add_option` method)
    # is included with the generator to store and retrieve
    # parser-specific options. `FileGenerator#context` is used within
    # a generator to access this value.
    getter context : C
    # The input gathered from the `Input` class. This starts
    # uninitialized, but is set partway through `#run`.
    getter input : I?
    # The list of registered file generators.
    getter file_gens : Array(FileGenerator(C, I))
    # The Crystal-native `OptionParser` used to actually
    # print options to the console.
    getter option_parser : OptionParser
    # Hash that stores the configured file names of the various
    # `FileGenerator` instances, associated with their internal names.
    # The file names are kept outside their generators so that
    # two generators that depend on one another (like a source file
    # including a header file) can know each other's names.
    getter output_file_names : Hash(String, String)

    # Create a new `PegasusOptionParser` with the given input method and context.
    def initialize(@input_method : Input(I), @context = C.new)
      @output = FilesOutputMode.new
      @file_gens = [] of FileGenerator(C, I)
      @option_parser = OptionParser.new
      @output_file_names = {} of String => String

      @input_method.add_option(self)
      @context.add_option(self)
      @option_parser.on("-S",
                        "--stdout",
                        "Sets output mode to standard output") do 
        @output = StdOutputMode.new
      end
      @option_parser.on("-s FILE",
                        "--single-file=FILE",
                        "Sets output mode to single file.") do |file|
        @output = FileOutputMode.new file
      end
      @option_parser.on("-f PREFIX",
                        "--file-prefix=PREFIX",
                        "Sets the file prefix for generated files.") do |p|
        @output_file_names.each do |k,v|
          @output_file_names[k] = p + v
        end
      end
      @option_parser.on("-H", "--help", "Show this text") do
        puts @option_parser
        exit
      end
    end

    # Run the command line program, and the constructed generator.
    def run
      @option_parser.parse
      @input = @input_method.process(self)
      @output.output(self)
    end
  end

  # A base class for a source file generator.
  # This class is meant to be extended by each individual
  # file generator that uses `ECR`, and thus provides
  # the methods `#input!` and `#context` to make
  # the genertor's input and context available inside
  # the template file.
  class FileGenerator(C, I)
    # The parser program to which this generator belongs,
    # used to retreive input and context and to configure
    # and retreive file names.
    property parent : PegasusOptionParser(C, I)
    # The internal name of this file generator, 
    # which will be associated with a filename by the `PegasusOptionParser`.
    property name : String
    # The default filename this generator will write to.
    property default_filename : String
    # The user-friendly description of this generator.
    property description : String

    # Creates a new file generator attached to he given `PegasusOptionParser`,
    # with the given name, default filename, and description.
    def initialize(@parent, @name, @default_filename, @description)
      @parent.file_gens << self
      add_option(@parent)
      @parent.output_file_names[@name] = @default_filename
    end

    # Adds required options to the given option parser.
    def add_option(opt_parser)
      opt_parser.option_parser.on("-#{name[0].downcase} FILE",
                                  "--#{name}-file=FILE",
                                  "Sets output target for #{description}") do |n|
        opt_parser.output_file_names[name] = n
      end
    end

    # Convenience method to access the parser generator input from
    # an ECR template.
    def input!
      @parent.input.not_nil!
    end

    # Convenience method to access the parser context from
    # an ECR template.
    def context
      @parent.context
    end
  end
end
