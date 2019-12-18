/* == Parsing Code == */

pgs_tree* pgs_create_tree_nonterminal(long int nonterminal, size_t child_count) {
    pgs_tree* tree = (pgs_tree*) malloc(sizeof(*tree));
    pgs_tree** children = (pgs_tree**) malloc(sizeof(*children) * child_count);

    if(tree == NULL || children == NULL) {
        free(tree);
        return NULL;
    }

    tree->variant = PGS_TREE_NONTERMINAL;
    tree->tree_data.nonterminal.nonterminal = nonterminal;
    tree->tree_data.nonterminal.child_count = child_count;
    tree->tree_data.nonterminal.children = children;

    return tree;
}

pgs_tree* pgs_create_tree_terminal(pgs_token* t) {
    pgs_tree* tree = (pgs_tree*) malloc(sizeof(*tree));
    if(tree == NULL) return NULL;

    tree->variant = PGS_TREE_TERMINAL;
    tree->tree_data.terminal.token = *t;

    return tree;
}

void pgs_free_tree_nonterminal(pgs_tree* t) {
    size_t i;
    for(i = 0; i < t->tree_data.nonterminal.child_count; i++) {
        pgs_free_tree(t->tree_data.nonterminal.children[i]);
    }
    free(t->tree_data.nonterminal.children);
    free(t);
}

void pgs_free_tree_terminal(pgs_tree* t) {
    free(t);
}

long int pgs_tree_table_index(pgs_tree* t) {
    switch(t->variant) {
        case PGS_TREE_TERMINAL:
            return PGS_TREE_T(*t);
        case PGS_TREE_NONTERMINAL: 
            return PGS_TREE_NT(*t) + 2 + PGS_MAX_TERMINAL;
    }
}

void pgs_free_tree(pgs_tree* t) {
    switch(t->variant) {
        case PGS_TREE_TERMINAL: pgs_free_tree_terminal(t); break;
        case PGS_TREE_NONTERMINAL: pgs_free_tree_nonterminal(t); break;
    }
}

pgs_error pgs_parse_stack_init(pgs_parse_stack* s) {
    s->capacity = 8;
    s->size = 1;
    s->data = (pgs_parse_stack_element*) malloc(sizeof(*(s->data)) * s->capacity);

    if(s->data == NULL) return PGS_MALLOC;
    s->data[0].tree = NULL;
    s->data[0].state = 1;

    return PGS_NONE;
}

pgs_error pgs_parse_stack_append(pgs_parse_stack* s, pgs_tree* tree, long int state) {
    if(s->capacity == s->size) {
        pgs_parse_stack_element* new_elements =
            (pgs_parse_stack_element*) realloc(
                s->data, sizeof(*new_elements) * s->capacity * 2);
        if(new_elements == NULL) return PGS_MALLOC;
        s->capacity *= 2;
        s->data = new_elements;
    }

    s->data[s->size].tree = tree;
    s->data[s->size].state = state;
    s->size++;

    return PGS_NONE;
}

pgs_error pgs_parse_stack_append_terminal(pgs_parse_stack* s, pgs_token* t) {
    pgs_error error;
    long int state;
    pgs_tree* tree = pgs_create_tree_terminal(t);
    if(tree == NULL) return PGS_MALLOC;
    state = parse_state_table[pgs_parse_stack_top_state(s)][t->terminal];
    error = pgs_parse_stack_append(s, tree, state);
    if(error) {
        pgs_free_tree_terminal(tree);
        return error;
    }
    return PGS_NONE;
}

pgs_error pgs_parse_stack_append_nonterminal(pgs_parse_stack* s, long int id, size_t count) {
    size_t i;
    pgs_tree** child_array;
    pgs_tree* new_tree;
    
    child_array = (pgs_tree**) malloc(sizeof(*child_array) * count);
    new_tree = pgs_create_tree_nonterminal(id, 0);
    if(child_array == NULL || new_tree == NULL) {
        free(child_array);
        return PGS_MALLOC;
    }
    for(i = 0; i < count; i++) {
        child_array[i] = s->data[s->size - count + i].tree;
    }

    new_tree->tree_data.nonterminal.nonterminal = id;
    new_tree->tree_data.nonterminal.child_count = count;
    new_tree->tree_data.nonterminal.children = child_array;

    s->size -= count;
    s->data[s->size].tree = new_tree;
    s->data[s->size].state = parse_state_table[pgs_parse_stack_top_state(s)][id + 2 + PGS_MAX_TERMINAL];
    s->size++;

    return PGS_NONE;
}

void pgs_parse_stack_free(pgs_parse_stack* s) {
    size_t i;
    for(i = 0; i < s->size; i++) {
        free(s->data[i].tree);
    }
    free(s->data);
}

long int pgs_parse_stack_top_state(pgs_parse_stack* s) {
    return s->data[s->size - 1].state;
}

pgs_tree* pgs_parse_stack_top_tree(pgs_parse_stack* s) {
    return s->data[s->size - 1].tree;
}

#define PGS_PARSE_ERROR(label_name, error_name, code, text) \
    error_name = code; \
    pgs_state_error(s, error_name, text); \
    goto label_name;

pgs_error pgs_do_parse(pgs_state* s, pgs_token_list* list, pgs_tree** into) {
    pgs_error error;
    pgs_parse_stack stack;
    pgs_tree* top_tree;
    long int top_state;
    long int tree_table_index;
    long int current_token_id;
    long int action;
    struct pgs_item_s* item;
    pgs_token* current_token; 
    size_t index = 0;
    
    if((error = pgs_parse_stack_init(&stack))) return error;
    while(1) {
        current_token_id = pgs_token_list_at_id(list, index);
        top_tree = pgs_parse_stack_top_tree(&stack);
        top_state = pgs_parse_stack_top_state(&stack);

        if(top_tree &&
                top_tree->variant == PGS_TREE_NONTERMINAL &&
                parse_final_table[top_tree->tree_data.nonterminal.nonterminal + 1])
            break;

        action = parse_action_table[top_state][current_token_id];

        if(action == -1) {
            PGS_PARSE_ERROR(error_label, error, PGS_BAD_TOKEN, "Unexpected token at position");
        } else if(action == 0) {
            current_token = pgs_token_list_at(list, index);
            if(index >= (list->token_count)) {
                PGS_PARSE_ERROR(error_label, error, PGS_EOF_SHIFT, "Unexpected end of file");
            }

            error = pgs_parse_stack_append_terminal(&stack, current_token);
            if(error) goto error_label;
            index++;
        } else {
            item = &items[action - 1];
            error = pgs_parse_stack_append_nonterminal(&stack, item->left_id, item->right_count);
        }
    }

    if(index != list->token_count) {
        PGS_PARSE_ERROR(error_label, error, PGS_BAD_TOKEN, "Unexpected token at position");
    }

    *into = stack.data[stack.size - 1].tree;
    stack.size -= 1;

    error_label:
    pgs_parse_stack_free(&stack);
    return error;
}

/* == Glue Code == */
pgs_error pgs_do_all(pgs_state* state, pgs_tree** into, const char* string) {
    pgs_error error;
    pgs_token_list tokens;
    pgs_state_init(state);
    *into = NULL;
    if((error = pgs_do_lex(state, &tokens, string))) {
        if(error == PGS_MALLOC) {
            pgs_state_error(state, error, "Failure to allocate memory while lexing");
        }
        return error;
    }
    if((error = pgs_do_parse(state, &tokens, into))) {
        if(error == PGS_MALLOC) {
            pgs_state_error(state, error, "Failure to allocate memory while lexing");
        }
    }
    pgs_token_list_free(&tokens);
    return error;
}
