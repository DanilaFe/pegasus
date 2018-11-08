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
## C Output
The pegasus repository contains the source code of a program that converts the JSON output into C source code. It generates a derivation tree, stored in `pgs_tree`, which is made up of nonterminal parent nodes and terminal leaves. Below is a simple example of using the functions generated for a grammar that describes the language of a binary operation applied to two numbers.
The grammar:
```
S = expr;
expr = number op number;
number = "[0-9]";
op = "\\+" | "-" || "\\*" || "/"
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
```
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
Some more useful C macros for accessing the trees can be found in `parser.h`
## Contributors

- [DanilaFe](https://github.com/DanilaFe) Danila Fedorin - creator, maintainer
