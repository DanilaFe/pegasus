require "json"

module Pegasus
  module Pda
    class Terminal
      JSON.mapping(
        id: { type: Int64, key: "terminal_id", setter: false }
      )
    end

    class Nonterminal
      JSON.mapping(
        id: { type: Int64, key: "nonterminal_id", setter: false }
      )
    end

    class Item
      JSON.mapping(
        head: { type: Nonterminal, setter: false },
        body: { type: Array(Terminal | Nonterminal), setter: false }
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

        terminals: { type: Hash(String, Pegasus::Pda::Terminal), setter: false },
        nonterminals: { type: Hash(String, Pegasus::Pda::Nonterminal), setter: false },
        items: { type: Array(Pegasus::Pda::Item), setter: false },
        max_terminal: { type: Int64, setter: false }
      )
    end
  end
end
