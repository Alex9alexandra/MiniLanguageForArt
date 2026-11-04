#pragma once
#ifndef FA_H
#define FA_H

// A deterministic finite automaton, loaded from a file

#define FA_MAX_STATES 64 // maximum number of states of one FA
#define FA_NAME_LEN   32 // maximum length of a state name

typedef struct {
    char name[FA_MAX_STATES][FA_NAME_LEN];// state names
    int  stateCount; // how many states
    int  start; // index of the start state
    int  isFinal[FA_MAX_STATES]; // 1 if the state is final
    int  next[FA_MAX_STATES][256]; // transition table: next[state][character]= next state, or -1 if there is none
} FA;

// Reads the FA from a file. Returns 1 if it is correct, 0 otherwise
int fa_load(FA* fa, const char* path);

// One step of the automaton: the state reached from 'state' by reading 'ch', or -1 if there is no such transition.
int fa_step(const FA* fa, int state, int ch);

// Returns 1 if 'state' is a final state.
int fa_is_final(const FA* fa, int state);

#endif