import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from translations import T, INFO

ROOT = os.path.join(os.path.dirname(__file__), "..", "Resources")

def escape(text):
    return text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")

def write(language, table, name):
    folder = os.path.join(ROOT, f"{language}.lproj")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, name), "w", encoding="utf-8") as output:
        for key in sorted(table):
            output.write(f"\"{escape(key)}\" = \"{escape(table[key])}\";\n")

for index, language in enumerate(["en", "es"]):
    write(language, {key: values[index] for key, values in T.items()}, "Localizable.strings")
    write(language, {key: values[index] for key, values in INFO.items()}, "InfoPlist.strings")
write("pt-BR", {key: key for key in T}, "Localizable.strings")
print(f"{len(T)} strings, {len(INFO)} Info.plist keys")
