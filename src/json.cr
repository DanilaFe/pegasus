require "json"

module Pegasus
  module Pda
    class Terminal
      JSON.mapping(
        id: { type: Int64, key: "terminal_id" }
      )
    end

    class Nonterminal
      JSON.mapping(
        id: { type: Int64, key: "nonterminal_id" }
      )
    end

    class Item
      JSON.mapping(
        head: Nonterminal,
        body: Array(Terminal | Nonterminal)
      )
    end
  end
  module Language
    class LanguageData
      JSON.mapping(
        lex_state_table: Array(Array(Int64)),
        lex_final_table: Array(Int64),
        parse_state_table: Array(Array(Int64)),
        parse_action_table: Array(Array(Int64)),

        terminals: Hash(String, Pegasus::Pda::Terminal),
        nonterminals: Hash(String, Pegasus::Pda::Nonterminal),
        items: Array(Pegasus::Pda::Item),
        max_terminal: Int64
      )
    end
  end
end
