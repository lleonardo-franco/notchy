import glob, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from translations import T

INTS = {"minutes", "level", "percent", "left", "right", "caseLevel", "count"}
PATTERNS = [
    r'String\(localized: "((?:[^"\\]|\\.)*)"',
    r'\b(?:Text|Label|Button|Toggle|Section|Picker|LabeledContent|TextField|Link|help|tip)\((?:"[^"]*",\s*)?"((?:[^"\\]|\\.)*)"',
    r'\b(?:title|help|text|detail|actionTitle|prompt): (?:[^"\n]*\? )?"((?:[^"\\]|\\.)*)"',
    r': "((?:[^"\\]|\\.)*)"\)',
]

def key_of(literal):
    out, i = "", 0
    while i < len(literal):
        if literal.startswith("\\(", i):
            depth, j = 1, i + 2
            while depth:
                depth += {"(": 1, ")": -1}.get(literal[j], 0)
                j += 1
            expr = literal[i + 2:j - 1]
            out += "%lld" if expr.startswith("Int(") or expr.split(" ")[0].split(".")[-1] in INTS or "/ 60" in expr else "%@"
            i = j
        elif literal.startswith('\\"', i):
            out += '"'
            i += 2
        elif literal[i] == "%":
            out += "%%"
            i += 1
        else:
            out += literal[i]
            i += 1
    return out

missing = set()
for path in sorted(glob.glob("Sources/Notchy/*.swift")):
    source = open(path, encoding="utf-8").read()
    for pattern in PATTERNS:
        for match in re.finditer(pattern, source):
            key = key_of(match.group(1))
            if not re.search(r"[A-Za-zÀ-ú]{2,}", key.replace("%lld", "").replace("%@", "")):
                continue
            if key not in T:
                missing.add((os.path.basename(path), key))
for item in sorted(missing):
    print(*item, sep=": ")
print(f"{len(missing)} not translated", file=sys.stderr)
