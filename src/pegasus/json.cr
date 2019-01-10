require "json"

module Pegasus
  class TerminalId
    JSON.mapping(
      id: { type: Int64, key: "terminal_id", setter: false, getter: false }
    )
  end

  class NonterminalId
    JSON.mapping(
      id: { type: Int64, key: "nonterminal_id", setter: false, getter: false },
      start: { type: Bool, setter: false, getter: false }
    )
  end

  module Pda
    class Item
      JSON.mapping(
        head: { type: NonterminalId, setter: false },
        body: { type: Array(TerminalId | NonterminalId), setter: false }
      )
    end
  end

  module Language
    class LanguageData
      JSON.mapping(
        lex_skip_table: { type: Array(Bool), setter: false },
        lex_state_table: { type: Array(Array(Int64)), setter: false },
        lex_final_table: { type: Array(Int64), setter: false },
        parse_state_table: { type: Array(Array(Int64)), setter: false },
        parse_action_table: { type: Array(Array(Int64)), setter: false },

        terminals: { type: Hash(String, Pegasus::TerminalId), setter: false },
        nonterminals: { type: Hash(String, Pegasus::NonterminalId), setter: false },
        items: { type: Array(Pegasus::Pda::Item), setter: false },
        max_terminal: { type: Int64, setter: false }
      )
    end
  end
end
