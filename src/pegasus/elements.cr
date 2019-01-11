module Pegasus
  class TerminalId
    # Creates a new TerminalId with the given ID.
    def initialize(@id : Int64)
    end

    def raw_id
      return @id
    end

    def table_index
      return @id + 1
    end

    # Compares this terminal to another terminal.
    def ==(other : TerminalId)
      return @id == other.@id
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

  class EmptyTerminalId < TerminalId
    def initialize
      @id = 0_i64
    end
    
    def raw_id
      raise_general "attempting to get raw ID of empty terminal", internal: true
    end

    def table_index
      raise_general "attempting to compute table index of empty terminal", internal: true
    end

    def ==(other : EmptyTerminalId)
      return true
    end

    def ==(other : TerminalId)
      return false
    end
  end

  class EofTerminalId < TerminalId
    def initialize
      @id = 0_i64
    end

    def raw_id
      raise_general "attempting to get raw ID of EOF terminal", internal: true
    end

    def table_index
      return 0_i64
    end

    def ==(other : EofTerminalId)
      return true
    end

    def ==(other : TerminalId)
      return false
    end
  end

  class NonterminalId
    # Creates a new NonterminalId with the given ID.
    def initialize(@id : Int64, @start = false)
    end

    def table_index
      return @id + 1
    end

    def start?
      return @start
    end

    # Compares this nonterminal to another nonterminal.
    def ==(other : NonterminalId)
      return (@id == other.@id) && (@start == other.@start)
    end

    # Creates a hash of this NonterminalId.
    def hash(hasher)
      @id.hash(hasher)
      @start.hash(hasher)
      hasher
    end

    def to_s(io)
      io << "NonterminalId(" << @id << ")"
    end
  end

  alias ElementId = TerminalId | NonterminalId
end
