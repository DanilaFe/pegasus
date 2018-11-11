# pegasus
A parser generator based on Crystal and the UNIX philosophy. It is language agnostic, but can
currently generate parsers for the [C](#c-output) and [Crystal](#crystal-output) languages.

_Warning: Pegasus is experimental. Its APIs are not yet solidified, and are subject to change at any time._

## Table of Contents
* [Architecture](#architecture)
* [Usage](#usage)
  * [Grammar Rules](#grammar-rules)
  * [Regular Expressions](#regular-expressions)
  * [Included Programs](#included-programs)
* [C Output](#c-output)
* [Crystal Output](#crystal-output)

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

### Regular Expressions
Regular
expressions support some basic operators:
* `hey+` matches `hey`, `heyy`, `heyyy`, and so on.
* `hey?` matches `hey` or `he`
* `hey*` matches `he`, `hey`, `heyy`, and so on.

Operators can also be applied to groups of characters:
* `(ab)+` matches `ab`, `abab`, `ababab`, and so on.

Please note, however, that Pegasus's lexer does not capture groups.

### Included programs
Before you use any of these programs, you should use
```
shards build --release
```
This will compile all the Pegasus programs in release mode,
for optimal performance.
#### `pegasus`
This program reads grammars from standard input, and generates
JSON descriptions out LALR automata,
which will be read by the other programs. For example:
```Bash
echo 'A="Hello, world!";' > test.grammar
./bin/pegasus < test.grammar
```
This prints the JSON to the command line. If you'd like to output
JSON to a file, you can use:
```Bash
./bin/pegasus < test.grammar > test.json
```
#### `pegasus-dot`
This program is used largely for debugging purpose, and generates GraphViz
DOT output, which can then by converted by the `dot` program into images.
This greatly helps with debugging generated automata. `pegasus-dot` simply
reads the generated JSON file:
```Bash
./bin/pegasus-dot < test.json
```
To generate a PNG from the DOT output, you need the `dot` program installed.
Once you have that, you can just pipe the output of `pegasus-dot` into `dot`:
```Bash
./bin/pegasus-dot < test.json | dot -Tpng -o visual.png
```
#### `pegasus-sim`
This is another program largely used for debugging. Instead of generating
a parser, it reads a JSON file, then attempts to parse text from STDIN.
Once it's done, it prints the result of its attempt. Note that because
it reads input from STDIN, rather than JSON, the JSON
file has to be given as a command-line argument:
```Bash
echo 'Hello, world!' | ./bin/pegasus-sim -i test.json
```

#### `pegasus-c`
Finally, a parser generator! `pegasus-c` takes JSON, and creates C
header and source files that can then be integrated into your project.
To learn how to use the generated code, please take a look at the
[C output](#c-output) section.
```Bash
./bin/pegasus-c < test.json
```

#### `pegasus-crystal`
Another parser generator. `pegasus-crystal` outputs Crystal code
which can then be integrated into your project.
To learn how to use the generated code, lease take a look at the
[Crystal output](#crystal-output) section.
```Bash
./bin/pegasus-crystal < test.json
```

## C Output
The pegasus repository contains the source code of a program that converts the JSON output into C source code. It generates a derivation tree, stored in `pgs_tree`, which is made up of nonterminal parent nodes and terminal leaves. Below is a simple example of using the functions generated for a grammar that describes the language of a binary operation applied to two numbers.
The grammar:
```
S = expr;
expr = number op number;
number = "[0-9]";
op = "\\+" | "-" || "\\*" || "/";
```
_note: backslashes are necessary in the regular expressions because `+` and `*` are operators in the regular expression language._

The code for the API:
```C
/* Include the generated header file */
#include "parser.h"
#include <stdio.h>

int main(int argc, char** argv) {
    pgs_state state; /* The state is used for reporting error messages.*/
    pgs_tree* tree; /* The tree that will be initialized */
    char buffer[256]; /* Buffer for string input */

    gets(buffer); /* Unsafe function for the sake of example */
    /* pgs_do_all lexes and parses the text from the buffer. */
    if(pgs_do_all(&state, &tree, buffer)) {
        /* A nonzero return code indicates error. Print it.*/
        printf("Error: %s\n", state.errbuff);
    } else {
        /* Do nothing, free the tree. */
        /* Tree is not initialized unless parse succeeds. */
        pgs_free_tree(tree);
    }
}
```
This example is boring because nothing is done with the tree. Let's walk the tree and print it out:
```C
void print_tree(pgs_tree* tree, const char* source, int indent) {
    size_t i;
    /* Print an indent. */
    for(i = 0; i < indent; i++) printf("  ");
    /* If the tree is a terminal (actual token) */
    if(tree->variant == PGS_TREE_TERMINAL) {
        printf("Terminal: %.*s\n", (int) (PGS_TREE_T_TO(*tree) - PGS_TREE_T_FROM(*tree)),
                source + PGS_TREE_T_FROM(*tree));
    } else {
        /* PGS_TREE_NT gives the nonterminal ID from the given tree. */
        printf("Nonterminal: %s\n", pgs_nonterminal_name(PGS_TREE_NT(*tree)));
        /* PGS_TREE_NT_COUNT returns the number of children a nonterminal
           node has. */
        for(i = 0; i < PGS_TREE_NT_COUNT(*tree); i++) {
            /* PGS_TREE_NT_CHILD gets the nth child of a nonterminal tree. */
            print_tree(PGS_TREE_NT_CHILD(*tree, i), source, indent + 1);
        }
    }
}
```
For the input string `3+3`, the program will output:
```
Nonterminal: S
  Nonterminal: expr
    Nonterminal: number
      Terminal: 3
    Nonterminal: op
      Terminal: +
    Nonterminal: number
      Terminal: 3
```
Some more useful C macros for accessing the trees can be found in `parser.h`
## Crystal Output
Just like with C, this repository contains a program to output Crystal when code given a JSON file.
Because Crystal supports exceptions and garbage collection, there is no need to initialize
any variables, or call corresponding `free` functions. The most basic example of reading
a line from the standard input and parsing it is below:
```Crystal
require "./parser.cr"

Pegasus::Generated.process(STDIN.gets.not_nil!)
```
Of course, this isn't particularly interesting. Let's add a basic function to print the tree:
```Crystal
def print(tree, indent = 0)
  indent.times { STDOUT << "  " }
  case tree
  when Pegasus::Generated::TerminalTree
    STDOUT << "Terminal: "
    STDOUT.puts tree.string
  when Pegasus::Generated::NonterminalTree
    STDOUT << "Nonterminal: " << tree.name
    STDOUT.puts
    tree.children.each { |it| print(it, indent + 1) }
  end
end
```
For the input string `3+3`, the program will output:
```
Nonterminal: S
  Nonterminal: expr
    Nonterminal: number
      Terminal: 3
    Nonterminal: op
      Terminal: +
    Nonterminal: number
      Terminal: 3
```

### JSON Format
For the grammar given by:
```
A = "hi";
```
The corresponding (pretty-printed) JSON output is:
```
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
