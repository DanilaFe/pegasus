require "./spec_utils.cr"

describe Pegasus::Language::LanguageDefinition do
  describe "#from_string" do
    it "Handles empty strings" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new ""
      end
    end

    it "Errors on just a rule without a body" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(rule S);
      end
    end

    it "Errors on just a token without a body" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(rule S);
      end
    end
    
    it "Errors on just a rule with an equals sign, but no body" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(rule S = );
      end
    end

    it "Errors on just a token with an equals sign, but no body" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(token S = );
      end
    end

    it "Errors on a token not ending in a semicolon, when another rule follows" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(token t = /t/\nrule expr = h;)
      end
    end

    it "Errors on a rule not ending in a semicolon, when another rule follows" do
      expect_raises(Pegasus::Error::GrammarException) do
        language = Pegasus::Language::LanguageDefinition.new %(rule S = expr\nrule expr = h;)
      end
    end


    it "Correctly parses a single rule with a single terminal or nonterminal" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = h;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ [ "h" ] ]
    end

    it "Correctly handles whitespace between the token / rule keyword and the identifier" do
      language = Pegasus::Language::LanguageDefinition.new %(token   \n  t   \n  = /t/;rule   \n  S  \n   = t;)
      language.tokens.size.should eq 1
      language.tokens["t"]?.should eq "t"
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ [ "t" ] ]
    end

    it "Correctly handles whitespace around the equals sign" do
      language = Pegasus::Language::LanguageDefinition.new %(token t   \n =    /t/;rule S   \n =    \nt;)
      language.tokens.size.should eq 1
      language.tokens["t"]?.should eq "t"
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ [ "t" ] ]
    end

    it "Correctly handles whitespace around the semicolon" do
      language = Pegasus::Language::LanguageDefinition.new %(token t = /t/   \n  ;   \n   rule S = t  \n  ;    \n)
      language.tokens.size.should eq 1
      language.tokens["t"]?.should eq "t"
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ [ "t" ] ]
    end

    it "Correctly handles whitespace between rule identifiers" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = hello   \n  goodbye   \n  |   \n   world;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ [ "hello", "goodbye" ], [ "world" ] ]
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
