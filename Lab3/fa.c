#include <stdio.h>
#include <string.h>
#include "fa.h"

#define FAIL(...) do { \
        fprintf(stderr, "%s, line %d: ", path, lineNo); \
        fprintf(stderr, __VA_ARGS__); \
        fprintf(stderr, "\n"); \
        fclose(f); \
        return 0; \
    } while (0)

// Returns the index of the state with this name, or -1
static int find_state(const FA* fa, const char* name) {
    int i;
    for (i = 0; i < fa->stateCount; i++) {
        if (strcmp(fa->name[i], name) == 0) {
            return i;
        }
    }
    return -1;
}

// A symbol is one character ('a') or a range ('a-z')
static int symbol_range(const char* token, int* from, int* to) {
    size_t n = strlen(token);
    if (n == 1) {
        *from = *to = (unsigned char)token[0];
        return 1;
    }
    if (n == 3 && token[1] == '-' && (unsigned char)token[0] <= (unsigned char)token[2]) {
        *from = (unsigned char)token[0];
        *to = (unsigned char)token[2];
        return 1;
    }
    return 0;
}

int fa_load(FA* fa, const char* path) {
    FILE* f = fopen(path, "r");
    char line[4096];
    int lineNo = 0;
    int inTransitions = 0;
    int inAlphabet[256] = { 0 };
    char startName[FA_NAME_LEN] = "";
    char finalNames[FA_MAX_STATES][FA_NAME_LEN];
    int finalCount = 0;
    int i, c;

    if (f == NULL) {
        fprintf(stderr, "Cannot open the FA file '%s'\n", path);
        return 0;
    }

    fa->stateCount = 0;
    fa->start = -1;
    for (i = 0; i < FA_MAX_STATES; i++) {
        fa->isFinal[i] = 0;
        for (c = 0; c < 256; c++) {
            fa->next[i][c] = -1;
        }
    }

    while (fgets(line, sizeof(line), f) != NULL) {
        char* text = line;
        char* token;
        lineNo++;

        while (*text == ' ' || *text == '\t') text++;                    
        text[strcspn(text, "\r\n")] = '\0';                             
        if (*text == '\0' || *text == '#') continue;                    

        if (strncmp(text, "states:", 7) == 0) {
            strtok(text, " \t");                                        
            while ((token = strtok(NULL, " \t")) != NULL) {
                if (fa->stateCount >= FA_MAX_STATES) FAIL("too many states (maximum %d)", FA_MAX_STATES);
                if (strlen(token) >= FA_NAME_LEN)    FAIL("state name '%s' is too long", token);
                if (find_state(fa, token) >= 0)      FAIL("state '%s' is declared twice", token);
                strcpy(fa->name[fa->stateCount++], token);
            }
        }
        else if (strncmp(text, "alphabet:", 9) == 0) {
            strtok(text, " \t");
            while ((token = strtok(NULL, " \t")) != NULL) {
                int from, to;
                if (!symbol_range(token, &from, &to)) FAIL("invalid symbol or range '%s'", token);
                for (c = from; c <= to; c++) inAlphabet[c] = 1;
            }
        }
        else if (strncmp(text, "start:", 6) == 0) {
            strtok(text, " \t");
            token = strtok(NULL, " \t");
            if (token == NULL || strlen(token) >= FA_NAME_LEN) FAIL("a start state is expected");
            strcpy(startName, token);
        }
        else if (strncmp(text, "final:", 6) == 0) {
            strtok(text, " \t");
            while ((token = strtok(NULL, " \t")) != NULL) {
                if (finalCount >= FA_MAX_STATES || strlen(token) >= FA_NAME_LEN) FAIL("invalid final state '%s'", token);
                strcpy(finalNames[finalCount++], token);
            }
        }
        else if (strncmp(text, "transitions:", 12) == 0) {
            inTransitions = 1;
        }
        else if (inTransitions) {
            char* from_name = strtok(text, " \t");
            char* symbol = strtok(NULL, " \t");
            char* to_name = strtok(NULL, " \t");
            int src, dst, from, to;

            if (from_name == NULL || symbol == NULL || to_name == NULL) {
                FAIL("a transition needs 3 parts: state symbol next_state");
            }
            src = find_state(fa, from_name);
            dst = find_state(fa, to_name);
            if (src < 0 || dst < 0)                     FAIL("unknown state in the transition");
            if (!symbol_range(symbol, &from, &to))      FAIL("invalid symbol or range '%s'", symbol);
            for (c = from; c <= to; c++) {
                if (!inAlphabet[c])                     FAIL("'%c' is not in the alphabet", c);
                if (fa->next[src][c] != -1)             FAIL("the FA is not deterministic ('%c' from %s appears twice)", c, from_name);
                fa->next[src][c] = dst;
            }
        }
        else {
            FAIL("unknown line '%s'", text);
        }
    }
    fclose(f);

    lineNo = 0;
    fa->start = find_state(fa, startName);
    if (fa->start < 0) {
        fprintf(stderr, "%s: the start state '%s' is not in the list of states\n", path, startName);
        return 0;
    }
    if (finalCount == 0) {
        fprintf(stderr, "%s: no final state defined\n", path);
        return 0;
    }
    for (i = 0; i < finalCount; i++) {
        int s = find_state(fa, finalNames[i]);
        if (s < 0) {
            fprintf(stderr, "%s: final state '%s' is not in the list of states\n", path, finalNames[i]);
            return 0;
        }
        fa->isFinal[s] = 1;
    }
    return 1;
}

int fa_step(const FA* fa, int state, int ch) {
    if (ch < 0 || ch > 255) {
        return -1;
    }
    return fa->next[state][ch];
}

int fa_is_final(const FA* fa, int state) {
    return fa->isFinal[state];
}