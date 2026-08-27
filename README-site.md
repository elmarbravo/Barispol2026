# Centro Médico Barispol — site público

Pacote pronto a publicar. HTML estático, sem compilação no navegador.

## Estrutura

```
site/
├── index.html          → página principal
├── contacto.html       → subpágina de leads: formulário que envia para o WhatsApp da recepção
├── gestor.html         → gestor de fotografias e vídeos (uso local, fora do site)
├── campanhas.json      → campanhas activas
├── .gitignore          → impede que o gestor vá para o site
├── robots.txt
├── sitemap.xml
├── media/
│   ├── galeria.json    → índice das fotografias e vídeos
│   └── (fotografias e vídeos)
├── assets/
│   ├── logo-barispol.png
│   └── facility.jpg
└── README.md
```

O `index.html` tem 46 KB. A versão anterior tinha 474 KB e descarregava cerca de 2 MB de bibliotecas em cada visita.

---

## 1. Publicar no GitHub Pages

1. Colocar o conteúdo desta pasta na raiz do repositório, com o `index.html` na raiz.
2. **Settings → Pages → Source: Deploy from a branch**, ramo `main`, pasta `/ (root)`.
3. **Settings → Pages → Custom domain**: `barispol.com`. Guardar.
4. No Cloudflare, apontar o DNS para o GitHub Pages e activar **Enforce HTTPS**.

O site está preparado para o endereço `https://barispol.com`. Se mudar, corrigir `canonical`, `og:url` e `og:image` no `index.html` e no `contacto.html`, o campo `url` dos dados estruturados, o `sitemap.xml` e o `robots.txt`.

---

## 2. Fotografias e vídeos — como actualizar

Abrir `gestor.html` no navegador (basta abrir o ficheiro, não precisa de estar publicado).

1. **Escolher os ficheiros** — arrastar as fotos ou os vídeos, ou colar o endereço de um vídeo do YouTube.
2. **Escrever a legenda** de cada um. É a frase que aparece por baixo no site.
3. **Ordenar** com as setas. As primeiras doze entradas são as que aparecem na página.
4. **Descarregar ficheiros renomeados** — o gestor corrige nomes com acentos, espaços e maiúsculas.
5. **Descarregar `galeria.json`**.
6. **Carregar no GitHub**: os ficheiros para a pasta `media/`, o `galeria.json` para `media/galeria.json`, substituindo o anterior.

A secção «As nossas instalações» aparece assim que houver pelo menos uma entrada e desaparece sozinha se o índice ficar vazio.

Formato de cada entrada:

```json
{ "tipo": "foto",     "ficheiro": "recepcao.jpg",  "legenda": "Recepção" }
{ "tipo": "video",    "ficheiro": "visita.mp4",    "legenda": "Visita guiada" }
{ "tipo": "youtube",  "id": "JDl3qNn3OqA",         "legenda": "Visita às instalações" }
```

Fotografias: JPG ou WEBP, lado maior de 1600 px, abaixo de 400 KB. Vídeos próprios: MP4 abaixo de 20 MB — acima disso, publicar no YouTube e usar o tipo `youtube`, que não pesa no site.

---

## 3. Subpágina de contactos — já funciona

O `contacto.html` é o destino a usar nos patrocínios das redes sociais. **Não precisa de configuração nenhuma.**

O visitante preenche quatro campos — nome, telefone, o que precisa e o seguro — e ao carregar em enviar abre-se o WhatsApp da recepção com o pedido já escrito e organizado:

```
Pedido de contacto pelo site do Barispol.

Nome: Ana Paula
Telefone: 923 456 789
Precisa de: Análises clínicas
Seguro: Fidelidade Angola
Veio de: instagram

Agradeço que me liguem para marcar.
```

A comercial trabalha a lista a partir da caixa do WhatsApp, que já usa todos os dias. O telefone é validado antes de enviar: tem de ter nove dígitos e começar por 9.

**Ligações para os patrocínios:**

```
https://barispol.com/contacto.html?origem=instagram
https://barispol.com/contacto.html?origem=facebook
https://barispol.com/contacto.html?origem=tiktok
```

A origem entra na mensagem, na linha «Veio de», para saber que rede trouxe cada contacto.

### Opcional — se quiser também a lista em Excel

O WhatsApp não produz uma folha de cálculo. Se quiser essa lista, crie um formulário no Microsoft Forms com estas perguntas e cole o identificador em `LEAD_FORM_ID`, no fim do `contacto.html`. Passa a aparecer uma segunda opção por baixo do botão verde, sem tirar nada ao que já lá está.

| Pergunta | Tipo |
|---|---|
| Nome completo | Texto, obrigatório |
| Telefone | Texto, obrigatório |
| Serviço que precisa | Escolha: Análises · Consulta de clínica geral · Pediatria · Ginecologia · Ecografia ou raio-X · Outro |
| Seguro de saúde | Escolha: Não tenho · Fidelidade · ENSA · Nossa · Sanlam · Aliança · Outro |
| Como nos encontrou | Escolha: Instagram · Facebook · Google · Indicação · Já sou utente |

**Regra de conteúdo:** o formulário pede nome, telefone, serviço e seguro. Não deve pedir sintomas, diagnósticos nem resultados de exames — isso trata-se na consulta, não num formulário do site.

---

## 4. Campanhas

O ficheiro `campanhas.json` alimenta a secção «Campanhas a decorrer». Sem entradas, a secção não aparece.

```json
[
  {
    "titulo": "Rastreio de tensão arterial",
    "resumo": "Medição gratuita para maiores de 40 anos.",
    "periodo": "1 a 30 de Setembro",
    "fim": "2026-09-30",
    "selo": "Gratuito",
    "link": "https://www.instagram.com/centromedico_barispol",
    "cta": "Ver publicação"
  }
]
```

O campo `fim` retira a campanha do site automaticamente quando a data passa.

---

## 5. SEO — o que já está feito

- Título e descrição orientados para o que as pessoas procuram: análises clínicas e consulta em Camama.
- `canonical`, Open Graph e cartão de partilha — a ligação partilhada no WhatsApp e no Instagram mostra imagem e texto.
- Dados estruturados `MedicalClinic` com morada, coordenadas, horário, contactos e serviços.
- Dados estruturados `FAQPage` — as perguntas frequentes podem aparecer directamente nos resultados do Google.
- `sitemap.xml` e `robots.txt`, com o gestor interno fora dos motores de busca.
- Oito grupos de análises com página própria por âncora — grávidas, pré-operatório, check-up, febre, diabetes, saúde da mulher, saúde do homem, admissão. É o conteúdo que traz pesquisas específicas.
- Imagens com dimensões declaradas e carregamento diferido.

Depois de publicar: registar o site no **Google Search Console**, submeter o `sitemap.xml` e criar o perfil no **Google Empresarial** com a mesma morada, horário e telefone que estão no site.

---

## 6. Segurança — onde ficam as senhas

**No site não fica nenhuma.** Uma senha escrita dentro de um ficheiro HTML é legível por qualquer visitante que abra o código-fonte. Foi esse o problema da versão anterior, onde a conta de administrador e a respectiva senha estavam à vista no `index.html` e repetidas no README.

O controlo de acesso vive em cada sistema, com a sua própria autenticação a sério:

| O que quer proteger | Onde está a senha |
|---|---|
| Alterar o conteúdo do site | Conta do **GitHub**, com verificação em dois passos activada |
| Chat, tarefas, calendário e drive da equipa | **Supabase Auth**, no Workspace |
| Processo do paciente, facturação, stock | **MetaGest**, que já tem login próprio |
| Respostas ao inquérito | Conta **Microsoft 365** da clínica |

### O gestor de ficheiros não leva senha

O `gestor.html` não publica nada sozinho — só prepara os ficheiros e o índice para descarregar. Quem altera o site é quem tem a conta do GitHub. Por isso:

- Guarde o `gestor.html` no seu computador e abra-o com dois cliques. Não precisa de estar publicado para funcionar.
- O `.gitignore` incluído já impede que ele vá para o site quando carregar a pasta no GitHub.
- Se ainda assim o publicar, fica marcado como não indexável e o `robots.txt` mantém-no fora dos motores de busca. Não é um risco, mas também não serve de nada estar lá.

### Antes de publicar

1. Trocar a senha `B@rispol2022`, que esteve exposta no `index.html` e dentro do `workspace.html` antigos, em **todos** os sistemas onde tenha sido reutilizada. Deve considerar-se comprometida.
2. Activar o Supabase Auth no Workspace e fechar as tabelas com regras de acesso por utilizador. Enquanto estiverem abertas, quem tiver a chave anónima lê e escreve o chat interno.
3. Confirmar que a chave `service_role` do Supabase não consta de nenhum ficheiro publicado.
4. Activar a verificação em dois passos na conta do GitHub. É essa conta que passa a ser a chave do site.

---

## 7. Serviços na página — porquê esta ordem

Ordem apurada no Query Report do MetaGest, 45.967 registos entre 2023 e Agosto de 2026, com os itens consolidados (pacote promocional e consulta contam como o mesmo serviço, todos os hemogramas como um só, gota espessa e pesquisa de plasmódio como um só).

| Serviço | 2026 |
|---|---:|
| Consulta de Clínica Geral | 20,5% |
| Farmácia interna | 10,0% |
| Hemograma | 7,7% |
| Consulta de Pediatria | 5,7% |
| Pesquisa de plasmódio | 5,2% |
| PCR — identificação de bactérias | 4,7% |
| Consulta de Ginecologia | 4,4% |
| Ecografia | 4,3% |
| Teste de dengue | 4,0% |

Para alterar um bloco, editar o `<article class="svc …">` correspondente no `index.html`. Os grupos de análises estão na secção `#analises`.

---

© 2026 Centro Médico Barispol · Camama, Luanda — Angola
