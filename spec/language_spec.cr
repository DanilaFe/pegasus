require "./spec_utils.cr"

describe Pegasus::Language::LanguageDefinition do
  describe "#from_string" do
    it "Handles empty strings" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new ""
      end
    end

    it "Errors on just a rule without a body" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new %(rule S);
      end
    end

    it "Errors on just a token without a body" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new %(rule S);
      end
    end

    it "Errors on just a rule with an equals sign, but no body" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new %(rule S = );
      end
    end

    it "Errors on just a token with an equals sign, but no body" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new %(token S = );
      end
    end

    it "Errors on a token not ending in a semicolon, when another rule follows" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new %(token t = /t/\nrule expr = h;)
      end
    end

    it "Errors on a rule not ending in a semicolon, when another rule follows" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new %(rule S = expr\nrule expr = h;)
      end
    end

    it "Errors when a duplicate token is declared" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new %(token t = /t/; token t = /r/;)
      end
    end

    it "Errors when a rule is named the same as a token" do
      expect_raises(Pegasus::Error::GrammarException) do
        Pegasus::Language::LanguageDefinition.new %(token t = /t/; rule t = t;)
      end
    end

    it "Correctly handles options" do
      language = Pegasus::Language::LanguageDefinition.new %(token hello = /hello/ [ skip ];)
      language.tokens.size.should eq 1
      language.tokens["hello"]?.should eq Pegasus::Language::Token.new("hello", [ "skip" ])
    end

    it "Correctly handles two rules with the same name" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = weird; rule S = not_weird;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ rule(rule_alternative("weird")), rule(rule_alternative("not_weird")) ]
    end

    it "Correctly parses a single rule with a single terminal or nonterminal" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = h;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ rule(rule_alternative("h")) ]
    end

    it "Correctly parses a single token declaration" do
      language = Pegasus::Language::LanguageDefinition.new %(token hello = /hello/;)
      language.tokens.size.should eq 1
      language.tokens["hello"]?.should eq Pegasus::Language::Token.new("hello")
      language.rules.size.should eq 0
    end

    it "Correctly parses a single rule with more than one terminal or nonterminal" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = hello world;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ rule(rule_alternative("hello", "world")) ]
    end

    it "Correctly parses a rule with multiple bodies" do
      language = Pegasus::Language::LanguageDefinition.new %(rule S = s | e;)
      language.tokens.size.should eq 0
      language.rules.size.should eq 1
      language.rules["S"]?.should eq [ rule(rule_alternative("s"), rule_alternative("e")) ]
    end

    # The following tests are run with both types of newlines (UNIX and DOS)
    # to make sure we still work on Windows.
    ["\n", "\r\n"].each do |nl|
      it "Correctly handles whitespace between the token / rule keyword and the identifier" do
        language = Pegasus::Language::LanguageDefinition.new %Q(token   #{nl}  t   #{nl}  = /t/;rule   #{nl}  S  #{nl}   = t;)
        language.tokens.size.should eq 1
        language.tokens["t"]?.should eq Pegasus::Language::Token.new("t")
        language.rules.size.should eq 1
        language.rules["S"]?.should eq [ rule(rule_alternative("t")) ]
      end

      it "Correctly handles whitespace around the equals sign" do
        language = Pegasus::Language::LanguageDefinition.new %Q(token t   #{nl} =    /t/;rule S   #{nl} =    #{nl}t;)
        language.tokens.size.should eq 1
        language.tokens["t"]?.should eq Pegasus::Language::Token.new("t")
        language.rules.size.should eq 1
        language.rules["S"]?.should eq [ rule(rule_alternative("t")) ]
      end

      it "Correctly handles whitespace around the semicolon" do
        language = Pegasus::Language::LanguageDefinition.new %Q(token t = /t/   #{nl}  ;   #{nl}   rule S = t  #{nl}  ;    #{nl})
        language.tokens.size.should eq 1
        language.tokens["t"]?.should eq Pegasus::Language::Token.new("t")
        language.rules.size.should eq 1
        language.rules["S"]?.should eq [ rule(rule_alternative("t")) ]
      end

      it "Correctly handles whitespace between rule identifiers" do
        language = Pegasus::Language::LanguageDefinition.new %Q(rule S = hello   #{nl}  goodbye   #{nl}  |   #{nl}   world;)
        language.tokens.size.should eq 0
        language.rules.size.should eq 1
        language.rules["S"]?.should eq [ rule(rule_alternative("hello", "goodbye"), rule_alternative("world")) ]
      end

      it "Correctly parses two rules with one body each" do
        language = Pegasus::Language::LanguageDefinition.new %Q(rule S = h;#{nl}rule expr = e;)
        language.tokens.size.should eq 0
        language.rules.size.should eq 2
        language.rules["S"]?.should eq [ rule(rule_alternative("h")) ]
        language.rules["expr"]?.should eq [ rule(rule_alternative("e")) ]
      end
    end
  end
end
