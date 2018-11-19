require "./spec_utils.cr"

describe Pegasus::Language::LanguageDefinition do
  describe "#from_string" do
    it "Handles empty strings" do
      language = Pegasus::Language::LanguageDefinition.new ""
      language.declarations.size.should eq 0
    end

    it "Errors on just a nonterminal without a body" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(S);
      end
    end

    it "Errors on just a nontemrinal and an equals sign" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(S=);
      end
    end

    it "Errors on a production not ending in a semicolon" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(S="h")
      end
    end

    it "Errors on a production not ending in a semicolon, when another production follows" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(S=expr\nexpr="h";)
      end
    end

    it "Correctly parses a single production with a single terminal" do
      language = Pegasus::Language::LanguageDefinition.new %(S = "h";)
      language.declarations.size.should eq 1
      language.declarations[0].head.should eq "S"
      language.declarations[0].bodies.size.should eq 1
      language.declarations[0].bodies[0].size.should eq 1
      language.declarations[0].bodies[0][0].should be_a Pegasus::Language::TerminalRegex
      language.declarations[0].bodies[0][0].as(Pegasus::Language::TerminalRegex)
        .regex.should eq "h"
    end

    it "Correctly parses a single production with a single nonterminal" do
      language = Pegasus::Language::LanguageDefinition.new %(S = expr;)
      language.declarations.size.should eq 1
      language.declarations[0].head.should eq "S"
      language.declarations[0].bodies.size.should eq 1
      language.declarations[0].bodies[0].size.should eq 1
      language.declarations[0].bodies[0][0].should be_a Pegasus::Language::NonterminalName
      language.declarations[0].bodies[0][0].as(Pegasus::Language::NonterminalName)
        .name.should eq "expr"
    end

    it "Correctly parses a single production with one terminal and one nonterminal" do
      language = Pegasus::Language::LanguageDefinition.new %(S = "h" expr;)
      language.declarations.size.should eq 1
      language.declarations[0].head.should eq "S"
      language.declarations[0].bodies.size.should eq 1
      language.declarations[0].bodies[0].size.should eq 2
      language.declarations[0].bodies[0][0].should be_a Pegasus::Language::TerminalRegex
      language.declarations[0].bodies[0][0].as(Pegasus::Language::TerminalRegex)
        .regex.should eq "h"
      language.declarations[0].bodies[0][1].should be_a Pegasus::Language::NonterminalName
      language.declarations[0].bodies[0][1].as(Pegasus::Language::NonterminalName)
        .name.should eq "expr"
    end

    it "Correctly parses a single production with multiple bodies" do
      language = Pegasus::Language::LanguageDefinition.new %(S = "h" | "e";)
      language.declarations.size.should eq 1
      language.declarations[0].head.should eq "S"
      language.declarations[0].bodies.size.should eq 2
      language.declarations[0].bodies[0].size.should eq 1
      language.declarations[0].bodies[0][0].should be_a Pegasus::Language::TerminalRegex
      language.declarations[0].bodies[0][0].as(Pegasus::Language::TerminalRegex)
        .regex.should eq "h"
      language.declarations[0].bodies[1].size.should eq 1
      language.declarations[0].bodies[1][0].should be_a Pegasus::Language::TerminalRegex
      language.declarations[0].bodies[1][0].as(Pegasus::Language::TerminalRegex)
        .regex.should eq "e"
    end

    it "Correctly parses two productions with one body each" do
      language = Pegasus::Language::LanguageDefinition.new %(S = "h";\nexpr = "w";)
      language.declarations.size.should eq 2
      language.declarations[0].head.should eq "S"
      language.declarations[0].bodies.size.should eq 1
      language.declarations[0].bodies[0].size.should eq 1
      language.declarations[0].bodies[0][0].should be_a Pegasus::Language::TerminalRegex
      language.declarations[0].bodies[0][0].as(Pegasus::Language::TerminalRegex)
        .regex.should eq "h"
      language.declarations[1].bodies.size.should eq 1
      language.declarations[1].bodies[0].size.should eq 1
      language.declarations[1].bodies[0][0].should be_a Pegasus::Language::TerminalRegex
      language.declarations[1].bodies[0][0].as(Pegasus::Language::TerminalRegex)
        .regex.should eq "w"
    end
  end
end
