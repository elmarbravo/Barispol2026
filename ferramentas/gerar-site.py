from urllib.parse import quote
WA = "244946373631"
def wa(texto): return "https://wa.me/%s?text=%s" % (WA, quote(texto))

grupos = [
 ("Análises da grávida", "Acompanhamento pré-natal, do primeiro trimestre ao parto.",
  "Hemograma completo, grupo sanguíneo e factor Rh, glicemia em jejum, urina II e urocultura, VDRL (sífilis), teste de HIV, hepatite B e C, toxoplasmose IgG e IgM, citomegalovírus, beta-HCG."),
 ("Pré-operatório", "O conjunto que o cirurgião ou o anestesista costuma pedir.",
  "Hemograma completo, tempo de coagulação, tempo de protrombina (TP e INR), grupo sanguíneo e factor Rh, glicemia em jejum, ureia e creatinina, TGO/AST e TGP/ALT, teste de HIV, hepatite B e C, raio-X do tórax."),
 ("Check-up geral", "Uma vez por ano, para quem se sente bem.",
  "Hemograma completo, glicemia em jejum, colesterol total, HDL e LDL, triglicéridos, ureia e creatinina, ácido úrico, TGO/AST e TGP/ALT, urina II, velocidade de sedimentação."),
 ("Febre e infecção", "Para febre, dores no corpo ou mal-estar sem causa aparente.",
  "Gota espessa (pesquisa de plasmódio), teste rápido de malária, teste de dengue NS1, teste rápido de chikungunya, reacção de Widal (febre tifóide), proteína C reactiva, PCR (identificação de bactérias), hemograma completo."),
 ("Diabetes e controlo metabólico", "Para quem já tem diagnóstico ou casos na família.",
  "Glicemia em jejum, hemoglobina glicada (HbA1c), colesterol total, HDL e LDL, triglicéridos, creatinina, microalbuminúria, ácido úrico."),
 ("Saúde da mulher", "Rotina ginecológica e queixas frequentes.",
  "Exsudado vaginal, urocultura com antibiograma, hemograma completo, ferro e ferritina, TSH e T4 livre, beta-HCG, teste rápido de gravidez."),
 ("Saúde do homem", "A partir dos 40 anos, ou com queixas urinárias.",
  "PSA total e PSA livre, espermograma, glicemia em jejum, colesterol total, HDL e LDL, ureia e creatinina, urina II."),
 ("Admissão e atestado", "Para emprego, bolsa, viagem ou renovação de documentos.",
  "Hemograma completo, análise de urina, exame de fezes, VDRL (sífilis), teste de HIV, hepatite B, glicemia em jejum, raio-X do tórax."),
]
servicos = [
 ("Análises clínicas", "Laboratório próprio. Não precisa de marcação. A maioria dos resultados fica pronta no mesmo dia.", "#analises", "Ver os grupos de análises", None),
 ("Clínica geral", "Consulta marcada ou no próprio dia. Pedimos os exames certos e passamos a receita.", wa("Olá, gostaria de marcar uma consulta de clínica geral."), "Marcar consulta", "servico_11"),
 ("Pediatria", "Primeira consulta, puericultura e consultas de rotina.", wa("Olá, gostaria de marcar uma consulta de pediatria."), "Marcar consulta", "servico_12"),
 ("Ginecologia e obstetrícia", "Consultas de rotina e acompanhamento da gravidez.", wa("Olá, gostaria de marcar uma consulta de ginecologia."), "Marcar consulta", "servico_13"),
 ("Ecografia", "Ecografias obstétricas e gerais, com marcação prévia e leitura por imagiologista.", "ecografia.html", "Tipos de ecografia e preparação", None),
 ("Raio-X", "Com marcação prévia.", wa("Olá, gostaria de marcar um raio-X."), "Marcar exame", "servico_07"),
 ("Outras especialidades", "Cardiologia, cirurgia, ortopedia e urologia. Indicamos os dias de consulta de cada médico.", wa("Olá, gostaria de saber os dias de consulta de uma especialidade."), "Perguntar", None),
 ("Enfermagem", "Tratamentos e cuidados de enfermagem.", wa("Olá, gostaria de serviços de enfermagem."), "Perguntar", None),
 ("Farmácia interna", "Levante a medicação prescrita logo a seguir à consulta.", None, None, None),
]
seguros = ["Aliança Seguros", "BIC Seguros", "ENSA Seguros", "Fidelidade Angola", "Fortaleza Seguros", "Giant Seguros", "Global Seguros", "Liberty & Trevo Seguros", "Medicare", "Mediplus", "Mundial Seguros", "Nossa Seguros", "Prefira Seguros", "Protteja Seguros", "Sanlam Angola", "Saúde Mais", "Sol Seguros", "STAS Seguros", "Super Seguros", "Tranquilidade", "Unisaúde", "Viva Seguros"]
faq = [
 ("Preciso de marcação para fazer análises?", "Não. Pode vir directamente ao laboratório dentro do horário. A marcação pelo WhatsApp reduz a espera."),
 ("Quanto tempo demora o resultado?", "A maioria das análises fica pronta no próprio dia. Quando um exame segue para um laboratório externo, indicamos o prazo no momento da colheita."),
 ("Qual é o horário?", "Abrimos todos os dias, das 07:30 às 22:00. Também aos fins de semana e feriados."),
 ("As ecografias precisam de marcação?", "Sim. Marcamos as ecografias com antecedência, pelo WhatsApp ou por telefone."),
 ("Têm farmácia no local?", "Sim. A farmácia interna entrega a medicação prescrita logo a seguir à consulta."),
 ("Onde ficamos?", "No Bairro Bom Sossego, Casa 186, em Camama, Luanda. Junto ao Hospital Materno Infantil Azancot de Menezes."),
]
def esc(s): return s.replace("&","&amp;").replace("<","&lt;")
def a_wa(href, texto, cod=None, cls=""):
    extra = ' target="_blank" rel="noopener"' if href.startswith("https://wa.me") else ""
    d = ' data-wa="%s"' % cod if cod else ""
    c = ' class="%s"' % cls if cls else ""
    return '<a%s href="%s"%s%s>%s</a>' % (c, href, extra, d, texto)

lin_serv = "\n".join(
 '      <div class="linha"><h3>%s</h3><div><p>%s</p>%s</div></div>' % (t, p, ('<p class="mais">'+a_wa(h,l,c)+'</p>') if h else "")
 for t,p,h,l,c in servicos)
lin_grupos = "\n".join(
 '      <div class="linha"><h3>%s<span>%s</span></h3><div><p>%s</p><p class="mais">%s</p></div></div>' %
 (n, r, ex, a_wa(wa("Olá, gostaria de marcar o grupo de análises: %s." % n), "Marcar este grupo", "servico_10"))
 for n,r,ex in grupos)
lis_seg = "\n".join('        <li>%s</li>' % s.replace('&','&amp;') for s in seguros)
lis_faq = "\n".join('      <details><summary>%s</summary><p>%s</p></details>' % (q,a) for q,a in faq)
import json
faq_ld = json.dumps({"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":q,"acceptedAnswer":{"@type":"Answer","text":a}} for q,a in faq]}, ensure_ascii=False, indent=1)

MARCAR = wa("Olá, gostaria de marcar.")
tpl = open(__file__.replace("gerar-site.py","modelo-site.html"), encoding="utf-8").read()
out = (tpl.replace("{{SERVICOS}}", lin_serv).replace("{{GRUPOS}}", lin_grupos)
          .replace("{{SEGUROS}}", lis_seg).replace("{{FAQ}}", lis_faq)
          .replace("{{FAQ_LD}}", faq_ld).replace("{{MARCAR}}", MARCAR)
          .replace("{{WA_ANALISES}}", wa("Olá, gostaria de saber se fazem uma análise específica.")))
open(__file__.replace("ferramentas/gerar-site.py","index.html"), "w", encoding="utf-8").write(out)
print(len(out))
