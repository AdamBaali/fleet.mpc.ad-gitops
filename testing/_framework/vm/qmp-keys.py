# Prints one QMP send-key command per character of argv[1], for qmp.sh type.
import json, sys
plain = {" ": "spc", "\\": "backslash", "/": "slash", ".": "dot", "-": "minus", "=": "equal",
         ",": "comma", ";": "semicolon", "'": "apostrophe", "\n": "ret"}
shifted = {":": "semicolon", "_": "minus", "+": "equal", '"': "apostrophe", "|": "backslash",
           "?": "slash", "<": "comma", ">": "dot", "!": "1", "@": "2", "#": "3", "$": "4",
           "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0"}
for c in sys.argv[1]:
    if c in shifted: keys = ["shift", shifted[c]]
    elif c.isupper(): keys = ["shift", c.lower()]
    else: keys = [plain.get(c, c)]
    print(json.dumps({"execute": "send-key",
                      "arguments": {"keys": [{"type": "qcode", "data": k} for k in keys]}}))
