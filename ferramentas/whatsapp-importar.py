#!/usr/bin/env python3
"""Importar a exportação de um grupo do WhatsApp para um canal do Workspace.

Método usado na Farmácia, Laboratório, Enfermagem e RP; ver O-QUE-FALTA 3-ao.

Uso:
  python3 ferramentas/whatsapp-importar.py _chat.txt \
      --canal c-radiologia --base 3000000 --prefixo wa-radiologia \
      --grupo "DC - RADIOLOGIA" --mapa mapa.json --saida /tmp/radiologia

  _chat.txt   o ficheiro de dentro do .zip «Exportar conversa» (sem ficheiros).
  --canal     conv_key do canal no Workspace (c-farmacia, c-laboratorio, …).
  --base      início dos ids negativos. Usados: Farmácia 1000000,
              Laboratório 2000000, Enfermagem 3000000, RP 4000000.
              O seguinte livre é 5000000.
  --prefixo   início do cid (evita repetir se se correr outra vez).
  --grupo     nome do grupo no WhatsApp: as linhas «escritas» por ele são
              avisos automáticos e ficam de fora.
  --mapa      JSON {"Nome no WhatsApp": "u13" | "x:Nome Curto"}. Fica FORA
              do repositório. Quem não tem conta leva «x:Nome».

Sai: rows.json e blocoN.sql (450 mensagens cada) na pasta --saida, e a soma
MD5 de cada bloco. Cada bloco aplica-se com apply_migration (MCP Supabase);
depois confere-se com a consulta impressa no fim. Durante o bloco, a tabela
messages sai da publicação supabase_realtime (não dispara avisos) e volta a
entrar no fim.

Regras (CLAUDE.md): o texto das conversas nunca entra no repositório; as
palavras-passe escritas no grupo ficam «[removida na importação]». O filtro
só apanha «senha: …» e chaves eyJ…/sb_secret_…: antes de aplicar, procurar
à mão palavras-passe soltas. Os caracteres invisíveis vão como «§a0§»,
«§2060§»… e o SQL repõe-nos (perdiam-se ao copiar o bloco).
"""
import argparse, collections, hashlib, json, os, re, sys, unicodedata

p = argparse.ArgumentParser()
p.add_argument('chat')
p.add_argument('--canal', required=True)
p.add_argument('--base', type=int, required=True)
p.add_argument('--prefixo', required=True)
p.add_argument('--grupo', default='')
p.add_argument('--mapa', required=True)
p.add_argument('--saida', required=True)
a = p.parse_args()

t = open(a.chat, encoding='utf-8').read()
Q = json.load(open(a.mapa, encoding='utf-8'))
os.makedirs(a.saida, exist_ok=True)

RX = re.compile(r'^[‎‏]?\[(\d{2})/(\d{2})/(\d{2,4}),? (\d{2}):(\d{2}):(\d{2})\] ([^:\n]+?):(?: |$)', re.M)
SIS = re.compile(r'^(As mensagens e chamadas são encriptadas|Criou o grupo|[^\n]* (definiu|adicionou|removeu|mudou|saiu|usou uma ligação do grupo)|Chamada de voz|Videochamada)')
ELIM = re.compile(r'^(Esta mensagem foi eliminada\.?|Eliminou esta mensagem( enquanto administrador/a)?\.?|[^\n]{0,80} (alterou|eliminou) a descrição do grupo|[^\n]{0,80} pediu para se juntar ao grupo|Adicionou [^\n]{0,60} ao grupo)$')
NV = ' (não veio na exportação do WhatsApp)'


def limpa(b):
    b = b.replace(' ', ' ').replace('⁨', '').replace('⁩', '').replace('\r', '')
    b = re.sub(r'([^\s‎][^\n‎]*?\.(?:pdf|docx?|xlsx?|pptx?|txt|csv))\s*•[^\n]*?‎?documento não revelado', lambda m: '📄 ' + m.group(1).strip() + NV, b)
    for de, para in [('documento não revelado', '📄 Documento'), ('imagem não revelada', '📷 Imagem'), ('vídeo não revelado', '🎬 Vídeo'),
                     ('ficheiro de áudio não revelado', '🎤 Áudio'), ('GIF não revelado', 'GIF'), ('Cartão de contacto omitido', '📇 Cartão de contacto')]:
        b = re.sub('‎?' + de, para + NV, b)
    b = b.replace('‎', '').replace('<Esta mensagem foi editada>', '').strip()
    b = unicodedata.normalize('NFC', b)  # acentos compostos (ex.: «ú» e não «u» + acento)
    b = re.sub(r'eyJ[\w.-]{10,}|sb_secret_\w+', '[chave removida na importação]', b)  # regra 1 do CLAUDE.md
    return re.sub(r'(?im)^(\s*(?:pass(?:word)?|senha|palavra-passe)\s*[:=]\s*)\S.*$', r'\1[removida na importação]', b)


ms = list(RX.finditer(t))
rows, fora, falta = [], collections.Counter(), set()
for i, m in enumerate(ms):
    quem = m.group(7).replace(' ', ' ').strip('‎ ~ ').strip()
    body = t[m.end(): ms[i + 1].start() if i + 1 < len(ms) else len(t)].rstrip('\n')
    raw = body.replace('‎', '').strip()
    if (a.grupo and quem == a.grupo) or (body.lstrip().startswith('‎') and SIS.match(raw)) or ELIM.match(raw) \
            or re.fullmatch(r'sticker não revelado', raw) or not raw:
        fora[raw[:40]] += 1
        continue
    if quem not in Q:
        falta.add(quem)
        continue
    d, mo, an, h, mi, s = m.group(1, 2, 3, 4, 5, 6)
    an = ('20' + an) if len(an) == 2 else an
    txt = limpa(body)
    if not txt:
        fora['vazio'] += 1
        continue
    rows.append((len(rows), Q[quem], f'{an}-{mo}-{d} {h}:{mi}:{s}', txt))

if falta:
    sys.exit('Remetentes sem mapa (acrescentar ao --mapa): ' + ', '.join(sorted(falta)))
print(len(rows), 'mensagens;', sum(fora.values()), 'linhas de fora')
print('de', rows[0][2], 'a', rows[-1][2])
print(collections.Counter(r[1] for r in rows).most_common())
json.dump(rows, open(os.path.join(a.saida, 'rows.json'), 'w'), ensure_ascii=False)

q = lambda x: "'" + x.replace("'", "''") + "'"
# Caracteres invisíveis perdem-se ao copiar o SQL: vão como «§a0§» e o SQL repõe-nos.
INV = {'\xa0': 160, '\u2060': 8288, '\u200b': 8203, '\ufe0f': 65039, '\t': 9}
qt = lambda x: q(''.join(f'§{c:x}§' if (c := INV.get(ch)) else ch for ch in x))
vt = 'v.t'
for c in INV.values():
    vt = f"replace({vt}, '§{c:x}§', chr({c}))"
for bi, k in enumerate(range(0, len(rows), 450)):
    bl = rows[k:k + 450]
    v = ',\n'.join(f"({r[0]},{q(r[1])},{q(r[2])},{qt(r[3])})" for r in bl)
    sql = ("alter publication supabase_realtime drop table public.messages;\n"
           "insert into public.messages (id, conv_key, user_id, text, cid, created_at) overriding system value\n"
           f"select -({a.base} + v.n), {q(a.canal)}, v.q, {vt}, {q(a.prefixo + '-')} || v.n, (v.ts || '+01')::timestamptz\nfrom (values\n"
           + v + f"\n) v(n, q, ts, t)\nwhere not exists (select 1 from public.messages m where m.cid = {q(a.prefixo + '-')} || v.n);\n"
           "alter publication supabase_realtime add table public.messages;\n")
    open(os.path.join(a.saida, f'bloco{bi}.sql'), 'w').write(sql)
    md5 = hashlib.md5('\n'.join(r[1] + '|' + r[2] + '|' + r[3] for r in bl).encode()).hexdigest()
    lo, hi = a.base + bl[0][0], a.base + bl[-1][0]
    print(f'bloco{bi}.sql: {len(bl)} mensagens, md5 {md5}')
    print(f"  conferir: select count(*), md5(string_agg(user_id || '|' || to_char(created_at at time zone 'Africa/Luanda', "
          f"'YYYY-MM-DD HH24:MI:SS') || '|' || text, E'\\n' order by id desc)) from messages where id between -{hi} and -{lo};")
