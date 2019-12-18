#define PGS_TREE_T(tree) ((tree).tree_data.terminal.token.terminal)
#define PGS_TREE_T_FROM(tree) ((tree).tree_data.terminal.token.from)
#define PGS_TREE_T_TO(tree) ((tree).tree_data.terminal.token.to)
#define PGS_TREE_NT(tree) ((tree).tree_data.nonterminal.nonterminal)
#define PGS_TREE_NT_COUNT(tree) ((tree).tree_data.nonterminal.child_count)
#define PGS_TREE_NT_CHILD(tree, n) ((tree).tree_data.nonterminal.children[n])
#define PGS_TREE_IS_NT(tree, type) (((tree).variant == PGS_TREE_NONTERMINAL) && (PGS_TREE_NT(tree) == (type)))

/* == Parsing Definitions == */
/**
 *  Enum that represents the variant of a parse tree,
 *  which is either a nonterminal with chilren, or a 
 *  terminal with a token.
 */
enum pgs_tree_variant_e {
    PGS_TREE_TERMINAL,
    PGS_TREE_NONTERMINAL
};

/**
 * The data of a terminal tree.
 */
struct pgs_tree_terminal_s {
    /** The token this tree holds. */
    pgs_token token;
};

/**
 * The data of a nonterminal tree.
 */
struct pgs_tree_nonterminal_s {
    /**
     * The nonterminal ID.
     */
    long int nonterminal;
    /**
     * The number of children this tree has.
     */
    size_t child_count;
    /**
     * The array of child pointers, allocated dynamically
     * depending on the item that reduced to this nonterminal.
     */
    struct pgs_tree_s** children;
};

/**
 * A general struct for a tree, which is either a terminal
 * or a nonterminal.
 */
struct pgs_tree_s {
    /** The variant of the tree. */
    enum pgs_tree_variant_e variant;
    union {
        /** The terminal variant of this tree. */
        struct pgs_tree_terminal_s terminal;
        /** The nonterminal variant of this tree. */
        struct pgs_tree_nonterminal_s nonterminal;
    } tree_data;
};

/**
 * An element on the parse stack, which holds
 * both a tree node and a state. In theory,
 * the stack is actually items followed by states,
 * but since one always comes after the other,
 * and since both need to be looked up fast,
 * we put them on a stack in parallel.
 */
struct pgs_parse_stack_element_s {
    /** The tree on the stack */
    struct pgs_tree_s* tree;
    /** The state on the stack */
    long int state;
};

/**
 * A parse stack. The PDA automaton
 * has to maintain this stack, where it gradually
 * assembles a tree.
 */
struct pgs_parse_stack_s {
    /** The number of stack elements currently allocated. */
    size_t capacity;
    /** The current number of stack elements. */
    size_t size;
    /** The stack element array. */
    struct pgs_parse_stack_element_s* data;
};

typedef enum pgs_tree_variant_e pgs_tree_variant;
typedef struct pgs_tree_terminal_s pgs_tree_terminal;
typedef struct pgs_tree_nontermnal_s pgs_tree_nonterminal;
typedef struct pgs_tree_s pgs_tree;
typedef struct pgs_parse_stack_element_s pgs_parse_stack_element;
typedef struct pgs_parse_stack_s pgs_parse_stack;

/**
 * Allocates and initialzie a parse tree node that is a nonterminal with the given
 * ID and the given child count.
 * @param nonterminal the nonterminal ID of this tree.
 * @param chil_count the number of chilren that this tree has.
 * @return the newly allocated tree, or NULL if a malloc failure occured.
 */
pgs_tree* pgs_create_tree_nonterminal(long int nonterminal, size_t child_count);
/**
 * Allocates and initialize a parse tree node that is a terminal with the given token.
 * @param t the token to initialize this tree with. The token need not be valid after this call.
 * @return the newly allocated tree, or NULL if a malloc failure occured.
 */
pgs_tree* pgs_create_tree_terminal(pgs_token* t);
/**
 * Frees a nonterminal tree.
 * @tree the tree to free.
 */
void pgs_free_tree_nonterminal(pgs_tree* tree);
/**
 * Frees a terminal tree.
 * @tree the tree to free.
 */
void pgs_free_tree_terminal(pgs_tree* tree);
/**
 * Computes the parser_action_table index for the given tree.
 * @param tree the tree for which to compute the index.
 * @return the index.
 */
long int pgs_tree_table_index(pgs_tree* tree);
/**
 * Frees a tree.
 * @param tree the tree to free.
 */
void pgs_free_tree(pgs_tree* tree);

/**
 * Initialzies a parse stack.
 * @param s the parse stack to initialize.
 * @return the result of the initialization.
 */
pgs_error pgs_parse_stack_init(pgs_parse_stack* s);
/**
 * Appends (pushes) a new tree and state to the stack.
 * @param s the stack to append to.
 * @param tree the tree to append.
 * @param state the state to append.
 * @return the result of the append.
 */
pgs_error pgs_parse_stack_append(pgs_parse_stack* s, pgs_tree* tree, long int state);
/**
 * Appends a given token to the stack, by initializing a new parse tree noe.
 * @param s the stack to append to.
 * @param t the token for which to construct a tree and compute a new state.
 * @return the result of the append.
 */
pgs_error pgs_parse_stack_append_terminal(pgs_parse_stack* s, pgs_token* t);
/**
 * Appends a given item to the stack, by popping the correct number of items
 * and creating a new nonterminal tree node in their place. A new state is also
 * computed from the nonterminal ID.
 * @param s the stack to append to.
 * @param id the nonterminal ID to create.
 * @param count the number of children to pop.
 * @return the result of the append.
 */
pgs_error pgs_parse_stack_append_nonterminal(pgs_parse_stack* s, long int id, size_t count);
/**
 * Gets the state on the top of the stack.
 * @param s the stack for which to get a state.
 * @return the state on the top of the stack.
 */
long int pgs_parse_stack_top_state(pgs_parse_stack* s);
/**
 * Gets the tree on the top of the stack.
 * @param s the stack for which to get a tree.
 * @return the tree on the top of the stack.
 */
pgs_tree* pgs_parse_stack_top_tree(pgs_parse_stack* s);
/**
 * Frees a parse stack, also freeing all the trees.
 * @param s the stack to free.
 */
void pgs_parse_stack_free(pgs_parse_stack* s);
/**
 * Takes the given tokens, and attempts to convert them into a parse tree.
 * @param s the state used for storing errors.
 * @param list the list of tokens, already filled.
 * @param into the tree pointer pointer into which a new tree will be stored.
 * @return the error, if any, that occured.
 */
pgs_error pgs_do_parse(pgs_state* s, pgs_token_list* list, pgs_tree** into);

/* == Glue == */
/**
 * Attempts to parse tokens from the given string into the given tree.
 * @param state the state to initialize with error information, if necessary.
 * @param into the tree to build into.
 * @param string the string from which to read.
 * @return the error, if any, that occured.
 */
pgs_error pgs_do_all(pgs_state* state, pgs_tree** into, const char* string);
