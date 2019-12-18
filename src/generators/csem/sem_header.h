/**
 * An element on the parse stack, which holds
 * both a tree node and a state. In theory,
 * the stack is actually items followed by states,
 * but since one always comes after the other,
 * and since both need to be looked up fast,
 * we put them on a stack in parallel.
 */
struct pgs_parse_stack_element_s {
    /** The value on the stack */
    union pgs_stack_value_u value;
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

typedef union pgs_stack_value_u pgs_stack_value;
typedef struct pgs_parse_stack_element_s pgs_parse_stack_element;
typedef struct pgs_parse_stack_s pgs_parse_stack;

/**
 * Initialzies a parse stack.
 * @param s the parse stack to initialize.
 * @return the result of the initialization.
 */
pgs_error pgs_parse_stack_init(pgs_parse_stack* s);
/**
 * Appends (pushes) a new value and state to the stack.
 * @param s the stack to append to.
 * @param v the value to append.
 * @param state the state to append.
 * @return the result of the append.
 */
pgs_error pgs_parse_stack_append(pgs_parse_stack* s, pgs_stack_value* v, long int state);
/**
 * Gets the state on the top of the stack.
 * @param s the stack for which to get a state.
 * @return the state on the top of the stack.
 */
long int pgs_parse_stack_top_state(pgs_parse_stack* s);
/**
 * Gets the value on the top of the stack.
 * @param s the stack for which to get a value.
 * @return the value on the top of the stack.
 */
pgs_stack_value* pgs_parse_stack_top_value(pgs_parse_stack* s);
/**
 * Frees a parse stack.
 * @param s the stack to free.
 */
void pgs_parse_stack_free(pgs_parse_stack* s);
/**
 * Takes the given tokens, and attempts to convert them into a value.
 * @param s the state used for storing errors.
 * @param list the list of tokens, already filled.
 * @param into the value pointer pointer into which a new value will be stored.
 * @param src the original string, for the user-defined actions.
 * @return the error, if any, that occured.
 */
pgs_error pgs_do_parse(pgs_state* s, pgs_token_list* list, pgs_stack_value* into, const char* src);

/* == Glue == */
/**
 * Attempts to parse tokens from the given string into the given value.
 * @param state the state to initialize with error information, if necessary.
 * @param into the value to build into.
 * @param string the string from which to read.
 * @return the error, if any, that occured.
 */
pgs_error pgs_do_all(pgs_state* state, pgs_stack_value* into, const char* string);
