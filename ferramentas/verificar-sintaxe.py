#!/usr/bin/env python3
# Junta os <script> sem src de uma página HTML num ficheiro .js, para o
# `node --check` confirmar que não há erros de sintaxe antes de publicar.
# Uso: python3 ferramentas/verificar-sintaxe.py workspace.html saida.js
import re
import sys

origem, destino = sys.argv[1], sys.argv[2]
html = open(origem, encoding="utf-8").read()
# Fica de fora o que não é JavaScript (JSON-LD, modelos de texto).
blocos = [
    corpo
    for atrib, corpo in re.findall(r"<script([^>]*)>(.*?)</script>", html, re.S)
    if "src=" not in atrib
    and not re.search(r"type=[\"'](?!text/javascript|module)", atrib)
]
with open(destino, "w", encoding="utf-8") as f:
    for i, b in enumerate(blocos):
        f.write(f"// --- bloco {i + 1} ---\n;(function(){{\n{b}\n}});\n")
print(f"{origem}: {len(blocos)} blocos de código")
