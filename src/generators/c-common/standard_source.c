#include <stdlib.h>
#include <string.h>

/* == General Code == */

void pgs_state_init(pgs_state* s) {
    s->error = PGS_NONE;
    s->errbuff[0] = '\0';
}

void pgs_state_error(pgs_state* s, pgs_error e, const char* message) {
    s->error = e;
    strncpy(s->errbuff, message, PGS_MAX_ERROR_LENGTH);
}

/* == Lexing Code == */

pgs_error pgs_token_list_init(pgs_token_list* l) {
    l->capacity = 8;
    l->token_count = 0;
    l->tokens = (pgs_token*) malloc(sizeof(*(l->tokens)) * l->capacity);

    if(l->tokens == NULL) return PGS_MALLOC;
    return PGS_NONE;
}

pgs_error pgs_token_list_append(pgs_token_list* l, long int terminal, size_t from, size_t to) {
    if(l->capacity == l->token_count) {
        pgs_token* new_tokens =
            (pgs_token*) realloc(l->tokens, sizeof(*new_tokens) * l->capacity * 2);
        if(new_tokens == NULL) return PGS_MALLOC;
        l->capacity *= 2;
        l->tokens = new_tokens;
    }

    l->tokens[l->token_count].terminal = terminal;
    l->tokens[l->token_count].from = from;
    l->tokens[l->token_count].to = to + 1;
    l->token_count++;

    return PGS_NONE;
}

pgs_token* pgs_token_list_at(pgs_token_list* l, size_t i) {
    return (i < l->token_count) ? &l->tokens[i] : NULL;
}

long int pgs_token_list_at_id(pgs_token_list* l, size_t i) {
    if(i < l->token_count) return l->tokens[i].terminal;
    return 0;
}

void pgs_token_list_free(pgs_token_list* l) {
    free(l->tokens);
}

pgs_error pgs_do_lex(pgs_state* s, pgs_token_list* list, const char* source) {
    pgs_error error;
    size_t index = 0;
    long int final;
    long int last_final;
    long int last_final_index;
    long int last_start;
    long int state;
    size_t length = strlen(source);

    if((error = pgs_token_list_init(list))) return error;
    while(!error && index < length) {
        last_final = -1;
        last_final_index = -1;
        last_start = index;
        state = 1;

        while(index < length && state) {
            state = lexer_state_table[state][(unsigned int) source[index]];

            if((final = lexer_final_table[state])) {
                last_final = final;
                last_final_index = index;
            }

            if(state) index++;
        }

        if(last_final == -1) break;
        if(lexer_skip_table[last_final]) continue;
        error = pgs_token_list_append(list, last_final, last_start, last_final_index);
    }

    if(error == PGS_MALLOC) {
        pgs_token_list_free(list);
    } else if (index != length) {
        pgs_state_error(s, PGS_BAD_CHARACTER, "Invalid character at position");
        pgs_token_list_free(list);
        return PGS_BAD_CHARACTER;
    }

    return PGS_NONE;
}
