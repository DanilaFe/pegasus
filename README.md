# pegasus
A parser generator based on Crystal and the UNIX philosophy.

## Architecture
Pegasus is based on the UNIX philosophy of doing one thing, and doing it well.
The core pegasus program isn't as much a parser generator as it is a Push Down 
Automaton generator.

Pegasus reads the grammar files, creates a Deterministic Finite Automaton (DFA) that is then used to tokenize (lex) text. Then, it creates an
LALR(1) Push Down Automaton that is then used to parse text. However, it doesn't actually generate a parser: it outputs the generated tables for both automatons,
as well as some extra information, as JSON. Another program, specific to each
language, then reads the JSON and is responsible for code output.

This is beneficial because this prevents the code generator from being dependent on a language. JSON is a data interchange format, and it is easily readable from almost any programming language. If I, or others, want to add a code generation target, they can just parse the JSON in their preferred language, rather than Crystal. An additional benefit is that the addition of a target doesn't require the pegasus core to be updated or recompiled.
## Usage
### Grammar Rules
Pegasus parses grammars written in very basic notation. The notation for
a single grammar rule is as follows:
```
S = "hello, world!";
```
This matches a single token, given by the regular expression `hello, world!`.
A rule can reference another rule:
```
S = AB;
A = "hello, ";
B = "world!";
```
Here, `S` matches `hello, world!` too, but creates a parse tree with `S` as root
and `A` and `B` as children.

Although it's possible to list a single nonterminal several times on the left han side of a rule, Pegasus also uses the `|` operator to add another alternative. This means that
```
A = B;
A = C;
```
is equivalent to
```
A = B | C;
```

### Regular expressions
Regular
expressions super some basic operators:
* `hey+` matches `hey`, `heyy`, `heyyy`, and so on.
* `hey?` matches `hey` or `he`
* `hey*` matches `he`, `hey`, `heyy`, and so on.

Operators can also be applied to groups of characters:
* `(ab)+` matches `ab`, `abab`, `ababab`, and so on.

Please note, however, that Pegasus's lexer does not capture groups.

### Sample Output
For the grammar given by:
```
A = "hi";
```
The corresponding (pretty-printed) JSON output is:
```JSON
{
  "lex_state_table":[[..]..],
  "lex_final_table”:[..],
  "parse_state_table":[[..]..],
  "parse_action_table":[[..]..],
  "terminals":{
    "hi":{
      "terminal_id":0
    }
  },
  "nonterminals":{
    "A":{
      "nonterminal_id":0
    }
  },
  "items":[
    {
      "head":{
        "nonterminal_id":0
      },
      "body":[
        {
          "terminal_id":0
        }
      ]
    }
  ],
  "max_terminal":0
}
```
## Contributors

- [DanilaFe](https://github.com/DanilaFe) Danila Fedorin - creator, maintainer
