import sys

DEFAULT_FILES = ["identifier.fa.txt", "number.fa.txt", "color.fa.txt"]

# Symbols and ranges
def expand(token):
    # Expands the ranges written as 1-9 to a list of [1,2,3,4,5,6,7,8,9]
    if len(token) == 1:
        return [token]
    if len(token) == 3 and token[1] == "-" and token[0] <= token[2]:
        return [chr(c) for c in range(ord(token[0]), ord(token[2]) + 1)]
    raise ValueError("invalid symbol or range: '" + token + "'")

# Reading the FA from a file
def read_fa(path):
    # Reads an FA file and returns it as a dictionary
    fa = {"states": [], "alphabet": [], "start": None,
          "final": [], "transitions": []}
    in_transitions = False

    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, start=1):
            line = line.strip()
            if line == "" or line.startswith("#"):
                continue
            if line.startswith("states:"):
                fa["states"] = line.split()[1:]
            elif line.startswith("alphabet:"):
                fa["alphabet"] = line.split()[1:]
            elif line.startswith("start:"):
                parts = line.split()
                if len(parts) != 2:
                    raise ValueError("line %d: exactly one start state expected" % number)
                fa["start"] = parts[1]
            elif line.startswith("final:"):
                fa["final"] = line.split()[1:]
            elif line.startswith("transitions:"):
                in_transitions = True
            elif in_transitions:
                parts = line.split()
                if len(parts) != 3:
                    raise ValueError("line %d: a transition needs 3 parts: "
                                     "state symbol next_state" % number)
                fa["transitions"].append((parts[0], parts[1], parts[2], number))
            else:
                raise ValueError("line %d: unknown line '%s'" % (number, line))
    return fa


def check_fa(fa):
    states = set(fa["states"])
    if not states:
        raise ValueError("no states defined")
    if fa["start"] not in states:
        raise ValueError("the start state is not in the list of states")
    for s in fa["final"]:
        if s not in states:
            raise ValueError("final state '%s' is not in the list of states" % s)
    if not fa["final"]:
        raise ValueError("no final state defined")

    alphabet = set()
    for token in fa["alphabet"]:
        alphabet.update(expand(token))

    used = set()
    for src, token, dst, number in fa["transitions"]:
        if src not in states or dst not in states:
            raise ValueError("line %d: unknown state in the transition" % number)
        for c in expand(token):
            if c not in alphabet:
                raise ValueError("line %d: '%s' is not in the alphabet" % (number, c))
            if (src, c) in used:
                raise ValueError("line %d: the FA is not deterministic "
                                 "('%s' from %s appears twice)" % (number, c, src))
            used.add((src, c))

def fa_to_rg(fa, expand_ranges=False):
    """
    Rule1: every state becomes a non-terminal; the start state becomes the start symbol.
    Rule2: every transition  A--a-->B  becomes the production  A->a B
    Rule3: if B is a final state, the production  A->a  is also added
    Rule4: if the start state is final (the FA accepts the empty word), a new start symbol S' is added with S' -> (productions of S) | epsilon
    Returns (non_terminals, terminals, start_symbol, productions)."""
    productions = {}

    for src, token, dst, _ in fa["transitions"]:
        symbols = expand(token) if expand_ranges else [token]
        for sym in symbols:
            rules = productions.setdefault(src, [])
            rules.append(sym + " " + dst)                  # rule 2
            if dst in fa["final"]:
                rules.append(sym)                          # rule 3

    non_terminals = list(fa["states"])
    start = fa["start"]

    if start in fa["final"]:                               # rule 4
        new_start = start + "'"
        productions[new_start] = list(productions.get(start, [])) + ["epsilon"]
        non_terminals.insert(0, new_start)
        start = new_start

    if expand_ranges:
        terminals = sorted({c for t in fa["alphabet"] for c in expand(t)})
    else:
        terminals = list(fa["alphabet"])
    return non_terminals, terminals, start, productions


def format_rg(non_terminals, terminals, start, productions):
    #Returns the grammar as text.
    lines = ["N     = {" + ", ".join(non_terminals) + "}",
             "Sigma = {" + ", ".join(terminals) + "}",
             "S     = " + start,
             "P:"]
    width = max(len(n) for n in productions)
    for n in non_terminals:
        if n in productions:
            lines.append("  " + n.ljust(width) + " -> " + " | ".join(productions[n]))
    return "\n".join(lines)


def main():
    args = sys.argv[1:]
    expand_ranges = "--expand" in args
    files = [a for a in args if a != "--expand"] or DEFAULT_FILES

    for path in files:
        print("-" * 70)
        print("FA file:", path)
        print()
        try:
            fa = read_fa(path)
            check_fa(fa)
        except (OSError, ValueError) as error:
            print("Error:", error)
            print()
            continue

        n, t, s, p = fa_to_rg(fa, expand_ranges)
        text = format_rg(n, t, s, p)
        print(text)
        print()

        out_path = path.replace(".fa.txt", "") + ".rg.txt"
        with open(out_path, "w", encoding="utf-8") as out:
            out.write(text + "\n")
        print("Grammar written to", out_path)
        print()


if __name__ == "__main__":
    main()