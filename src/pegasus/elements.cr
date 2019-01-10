module Pegasus
  class TerminalId
    # Special ID used for the end-of-file character
    SPECIAL_EOF = -1_i64
    # Special ID used for the "empty" string in FIRST set computation
    SPECIAL_EMPTY = -2_i64

    # The ID of this terminal.
    getter id : Int64

    # Creates a new TerminalId with the given ID.
    def initialize(@id)
    end

    # Compares this terminal to another terminal.
    def ==(other : TerminalId)
      return @id == other.id
    end

    # Creates a hash of this TerminalId.
    def hash(hasher)
      @id.hash(hasher)
      hasher
    end

    def to_s(io)
      io << "TerminalId(" << @id << ")"
    end
  end

  class NonterminalId
    # The ID of this nonterminal.
    getter id : Int64

    # Creates a new NonterminalId with the given ID.
    def initialize(@id)
    end

    # Compares this nonterminal to another nonterminal.
    def ==(other : NonterminalId)
      return @id == other.id
    end

    # Creates a hash of this NonterminalId.
    def hash(hasher)
      @id.hash(hasher)
      hasher
    end

    def to_s(io)
      io << "NonterminalId(" << @id << ")"
    end
  end

  alias ElementId = TerminalId | NonterminalId
end
