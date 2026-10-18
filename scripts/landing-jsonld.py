# Gera o JSON-LD da landing (@graph: marca, site, app, FAQ) e troca o bloco no <head>.
# O FAQPage sai do FAQ visível, então rode depois de mudar qualquer pergunta ou resposta:
#   python3 scripts/landing-jsonld.py [docs/index.html]
import html, json, re, sys
p = sys.argv[1] if len(sys.argv) > 1 else 'docs/index.html'; s = open(p, encoding='utf-8').read()
faq = s[s.index('<section class="section faq" id="faq">'):]
faq = faq[:faq.index('</section>')]
pairs = re.findall(r'<summary data-i18n="(q\d+)\.q">(.*?)</summary>\s*<p data-i18n="\1\.a">(.*?)</p>', faq, re.S)
clean = lambda t: re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', t)).replace('\xa0', ' ')).strip()
qa = [(clean(q), clean(a)) for _, q, a in pairs]
assert len(qa) == faq.count('<details>'), (len(qa), faq.count('<details>'))
SITE = 'https://carburante.motorcycles/'
STORE = 'https://apps.apple.com/br/app/carburante/id6785659437'
graph = {
  '@context': 'https://schema.org',
  '@graph': [
    {'@type': 'Organization', '@id': SITE + '#org', 'name': 'Carburante', 'url': SITE,
     'logo': SITE + 'assets/icon-256.png',
     'sameAs': ['https://www.instagram.com/carburante.app/', 'https://www.reddit.com/r/carburante/', 'https://github.com/wagnerrosa/carburante']},
    {'@type': 'WebSite', '@id': SITE + '#website', 'url': SITE, 'name': 'Carburante', 'inLanguage': 'pt-BR',
     'publisher': {'@id': SITE + '#org'}},
    {'@type': 'MobileApplication', '@id': SITE + '#app', 'name': 'Carburante',
     'description': 'App para iPhone que registra os abastecimentos da moto e mostra o consumo real (km/l), de tanque cheio a tanque cheio, com aviso antes da manutenção.',
     'url': SITE, 'image': SITE + 'assets/icon-256.png', 'screenshot': SITE + 'assets/og.png',
     'operatingSystem': 'iOS 18.0 ou mais recente', 'applicationCategory': 'UtilitiesApplication',
     'inLanguage': 'pt-BR', 'countriesSupported': 'BR', 'installUrl': STORE, 'sameAs': [STORE],
     'featureList': [
       'Registro de abastecimento com leitura da foto do hodômetro e do cupom no próprio iPhone',
       'Consumo real em km/l, de tanque cheio a tanque cheio',
       'Gráfico de consumo por período',
       'Histórico e lembrete de troca de óleo e manutenção',
       'Lançamento de abastecimentos antigos',
       'Conquistas e nível do perfil pelo uso real',
       'Várias motos na garagem, cada uma com seu histórico (Carburante Premium, opcional)'],
     'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'BRL'},
     'author': {'@type': 'Person', 'name': 'Wagner Rosa', 'url': 'https://wagnerrosa.com'},
     'publisher': {'@id': SITE + '#org'}},
    {'@type': 'FAQPage', '@id': SITE + '#faq', 'inLanguage': 'pt-BR',
     'mainEntity': [{'@type': 'Question', 'name': q, 'acceptedAnswer': {'@type': 'Answer', 'text': a}} for q, a in qa]},
  ]}
body = json.dumps(graph, ensure_ascii=False, indent=2)
body = '\n'.join('  ' + l for l in body.split('\n'))
block = ('  <!-- Dados estruturados (Google + assistentes de IA): marca, site, app e FAQ num @graph. O FAQPage\n'
         '       espelha o FAQ visível: mudou pergunta ou resposta, rode scripts/landing-jsonld.py. -->\n'
         '  <script type="application/ld+json">\n' + body + '\n  </script>')
old = re.search(r'(  <!-- Dados estruturados[^\n]*\n[^\n]*-->\n)?  <script type="application/ld\+json">.*?</script>', s, re.S)
assert old, 'bloco ld+json não achado'
s = s[:old.start()] + block + s[old.end():]
open(p, 'w', encoding='utf-8').write(s)
print(len(qa), 'perguntas'); [print(' -', q) for q, _ in qa]
