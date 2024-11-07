require "json"

module Pegasus
  class Elements::TerminalId
    include JSON::Serializable
    @[JSON::Field(key: "terminal_id")]
    @id : Int64
  end

  class Elements::NonterminalId
    include JSON::Serializable
    @[JSON::Field(key: "nonterminal_id")]
    @id : Int64
    @start : Bool
  end

  module Pda
    class Item
      include JSON::Serializable
      getter head : Elements::NonterminalId
      getter body : Array(Elements::TerminalId | Elements::NonterminalId)
    end
  end

  module Language
    class LanguageData
      include JSON::Serializable
      getter lex_skip_table : Array(Bool)
      getter lex_state_table : Array(Array(Int64))
      getter lex_final_table : Array(Int64)
      getter parse_state_table : Array(Array(Int64))
      getter parse_action_table : Array(Array(Int64))
      getter parse_final_table : Array(Bool)

      getter terminals : Hash(String, Elements::TerminalId)
      getter nonterminals : Hash(String, Elements::NonterminalId)
      getter items : Array(Pda::Item)
      getter max_terminal : Int64
    end
  end
end
