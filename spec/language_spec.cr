require "./spec_utils.cr"

describe Pegasus::Language::LanguageDefinition do
  describe "#from_string" do
    it "Handles empty strings" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new ""
      end
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

    it "Correctly parses a single rule with a single terminal or nonterminal" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = h;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ [ "h" ] ]
    end

    it "Correctly parses a single token declaration" do
      language = Pegasus::Language::LanguageDefinition.new %(token hello = /hello/;)
      language.tokens.size.should eq 1
      language.tokens["hello"]?.should eq "hello"
      language.rules.size.should eq 0
    end

    it "Correctly parses a single rule with more than one terminal or nonterminal" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = hello world;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ [ "hello", "world" ] ]
    end

    it "Correctly parses a rule with multiple bodies" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = s | e;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ [ "s" ], [ "e" ] ]
    end

    it "Correctly parses two rules with one body each" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = h;\nrule expr = e;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 2
      language.rules["S"]?.should eq [ [ "h" ] ]
      language.rules["expr"]?.should eq [ [ "e" ] ]
    end
  end
end
