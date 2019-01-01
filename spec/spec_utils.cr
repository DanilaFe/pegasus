require "./spec_helper"

def nonterminal(id)
  Pegasus::Pda::Nonterminal.new id.to_i64
end

def terminal(id)
  Pegasus::Pda::Terminal.new id.to_i64
end

def body(*elements)
  array = [] of Pegasus::Pda::Element
  array.concat elements.to_a
  return array
end

def item(head, body)
  Pegasus::Pda::Item.new head, body
end

def pda(*items)
  terminals = Set(Pegasus::Pda::Terminal).new
  nonterminals = Set(Pegasus::Pda::Nonterminal).new

  items.to_a.each do |item|
    nonterminals << item.head
    item.body.each do |element|
      case element
      when Pegasus::Pda::Terminal
        terminals << element
      when Pegasus::Pda::Nonterminal
        nonterminals << element
      end
    end
  end

  grammar = Pegasus::Pda::Grammar.new terminals: terminals.to_a,
    nonterminals: nonterminals.to_a
  items.to_a.each do |item|
    grammar.add_item item
  end
  lr_pda = grammar.create_lr_pda nonterminals.select(&.id.==(0)).first
  lalr_pda = grammar.create_lalr_pda lr_pda
  return lalr_pda
end

class Pegasus::State(V, T)
  def pattern_id
    @data.compact_map(&.data).max_of?(&.+(1)) || 0_i64
  end

  def path(length, &block)
    current = self
    length.times do
      current = current.transitions
        .select { |k, _| yield k }
        .first?.try &.[1]
      break unless current
    end
    return current
  end

  def lambda_path(length)
    path length, &.is_a?(Pegasus::Nfa::LambdaTransition)
  end

  def straight_path(length)
    path(length) { true }
  end
end

class ExceptionRule(T, R)
  getter index : Int32
  getter should : T?
  getter should_not : R?

  def initialize(@index, @should = nil, @should_not = nil)
  end
end

class Array(T)
  def all_should(should, *exceptions)
    each_with_index do |item, index|
      is_exception = false
      exceptions.each do |exception|
        if exception.index == index
          if should_rule = exception.should
            item.should should_rule
          end
          if should_not_rule = exception.should_not
            item.should_not should_not_rule
          end
          is_exception = true
        end
      end
      item.should should unless is_exception
    end
  end
end

def except(index : Int32, should : T? = nil, should_not : R? = nil) forall T, R
  ExceptionRule(T, R).new index, should, should_not
end
