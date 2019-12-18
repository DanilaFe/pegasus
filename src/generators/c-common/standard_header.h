#include <stdlib.h>
#include <string.h>

/**
 * Converts a nonterminal value to a string.
 * @param nt the nonterminal ID.
 * @return the name for the nonterminal.
 */
const char* pgs_nonterminal_name(long int nt);

/* == Generated Data Definitions == */
/**
 * A grammar item. A lot of the information collected by the parser
 * generate is not carried into the source code, which leaves items
 * as simply a nonterminal ID and the size of the right hand side.
 */
struct pgs_item_s {
    /** The nonterminal that this item is reduced to. */
    long int left_id;
    /**
     * The size of the item body, used to pop off
     * the correct number of states from the stack.
     */
    size_t right_count;
};

typedef struct pgs_item_s pgs_item;

/* == General Definitions == */
#define PGS_MAX_ERROR_LENGTH 255

/**
 * The types of errors that can occur while the
 * entire parsing process.
 */
enum pgs_error_e {
    /** No error occured. */
    PGS_NONE = 0,
    /** An allocation failed. */
    PGS_MALLOC,
    /** A token couldn't be recognized. */
    PGS_BAD_CHARACTER,
    /** A tree couldn't be recognized.  */
    PGS_BAD_TOKEN,
    /** End of file reached where it was not expected */
    PGS_EOF_SHIFT
};

/**
 * State used to report errors and their corresponding
 * messages.
 */
struct pgs_state_s {
    /** The error code. */
    enum pgs_error_e error;
    /** The error message. */
    char errbuff[PGS_MAX_ERROR_LENGTH];
};

typedef enum pgs_error_e pgs_error;
typedef struct pgs_state_s pgs_state;

/**
 * Initializes a state with no error.
 * @param s the state to initialize.
 */
void pgs_state_init(pgs_state* s);
/**
 * Sets the state to have an error.
 * @param s the state to initialize.
 * @param err the error message to return.
 */
void pgs_state_error(pgs_state* s, pgs_error err, const char* message);

/* == Lexing Definitions ==*/
/**
 * A token produced by lexing.
 */
struct pgs_token_s {
    /** The ID of the terminal. */
    long int terminal;
    /** The index at which the token starts. */
    size_t from;
    /** The index at which the next token begins. */
    size_t to;
};

/**
 * A dynamic list of tokens produced while lexing.
 */
struct pgs_token_list_s {
    /** The size of the currently allocated block of tokens */
    size_t capacity;
    /** The number of tokens in the list. */
    size_t token_count;
    /** The token data array. */
    struct pgs_token_s* tokens;
};

typedef struct pgs_token_s pgs_token;
typedef struct pgs_token_list_s pgs_token_list;

/**
 * Initializes a token list.
 * @param l the list to initialize.
 * @return any errors that occured while initializing the list.
 */
pgs_error pgs_token_list_init(pgs_token_list* l);
/**
 * Appends a token to the list.
 * @param terminal the ID of the terminal to append.
 * @param from the index at which the token begins.
 * @param to the index at which the next token begins.
 */
pgs_error pgs_token_list_append(pgs_token_list* l, long int terminal, size_t from, size_t to);
/**
 * Returns a token at the given index.
 * @param l the list to return a token from.
 * @param i the index from which to return a token.
 * @return a token, or NULL if the index is out of bounds.
 */
pgs_token* pgs_token_list_at(pgs_token_list* l, size_t i);
/**
 * Returns a token ID at the given index.
 * @param l the list to return an ID from.
 * @param i the index from which to return an ID.
 * @return returns an ID, or 0, which represents EOF.
 */
long int pgs_token_list_at_id(pgs_token_list* l, size_t i );
/**
 * Frees a list of tokens. Since the tokens are owned by the list,
 * they are invalidated after this call too.
 * @param l the list to free.
 */
void pgs_token_list_free(pgs_token_list* l);
/**
 * Performs a lexing operation.
 * @param s the state to populate with error text, if necessary.
 * @param list the list of tokens to initialize and populate.
 * @param source the string to lex.
 * @return the error, if any, that occured during this process.
 */
pgs_error pgs_do_lex(pgs_state* s, pgs_token_list* list, const char* source);

