/* == Glue Code == */

pgs_error pgs_do_all(pgs_state* state, pgs_stack_value* into, const char* string) {
    pgs_error error;
    pgs_token_list tokens;
    pgs_state_init(state);
    if((error = pgs_do_lex(state, &tokens, string))) {
        if(error == PGS_MALLOC) {
            pgs_state_error(state, error, "Failure to allocate memory while lexing");
        }
        return error;
    }
    if((error = pgs_do_parse(state, &tokens, into, string))) {
        if(error == PGS_MALLOC) {
            pgs_state_error(state, error, "Failure to allocate memory while lexing");
        }
    }
    pgs_token_list_free(&tokens);
    return error;
}

/* == Parsing Code == */

pgs_error pgs_parse_stack_init(pgs_parse_stack* s) {
    s->capacity = 8;
    s->size = 1;
    s->data = (pgs_parse_stack_element*) malloc(sizeof(*(s->data)) * s->capacity);

    if(s->data == NULL) return PGS_MALLOC;
    s->data[0].state = 1;

    return PGS_NONE;
}

pgs_error pgs_parse_stack_append(pgs_parse_stack* s, pgs_stack_value* v, long int state) {
    if(s->capacity == s->size) {
        pgs_parse_stack_element* new_elements =
            (pgs_parse_stack_element*) realloc(
                s->data, sizeof(*new_elements) * s->capacity * 2);
        if(new_elements == NULL) return PGS_MALLOC;
        s->capacity *= 2;
        s->data = new_elements;
    }

    s->data[s->size].value = *v;
    s->data[s->size].state = state;
    s->size++;

    return PGS_NONE;
}

void pgs_parse_stack_free(pgs_parse_stack* s) {
    size_t i;
    for(i = 0; i < s->size; i++) {
        /* Maybe eventually free individual union values */
    }
    free(s->data);
}

long int pgs_parse_stack_top_state(pgs_parse_stack* s) {
    return s->data[s->size - 1].state;
}

pgs_stack_value* pgs_parse_stack_top_value(pgs_parse_stack* s) {
    return &s->data[s->size - 1].value;
}

#define PGS_PARSE_ERROR(label_name, error_name, code, text) \
    error_name = code; \
    pgs_state_error(s, error_name, text); \
    goto label_name;

