#!/usr/bin/env python3
"""Monta a Ajuda do site (docs/ajuda/) a partir de content/ajuda/*.md.

Uma pergunta por página, texto no HTML (sem depender de JS, que a maioria dos
rastreadores de IA não roda). Além das páginas, o script mantém em sincronia:
  - docs/llms.txt      → seção "Manual" entre <!-- ajuda:start --> e <!-- ajuda:end -->
  - docs/llms-full.txt → o manual inteiro num arquivo só, em Markdown
  - docs/sitemap.xml   → URLs da Ajuda entre os mesmos marcadores

Uso: python3 scripts/build-ajuda.py   (idempotente; rode depois de editar content/ajuda/)

Formato de cada .md: front matter entre linhas '---' (slug, title, nav, section,
order, description, updated, related) e um Markdown pequeno: ## / ###, parágrafos,
listas '- ' e '1. ', '> ' (nota), tabelas '|' e, no texto, **negrito** e [link](url).
O primeiro parágrafo é a resposta curta (destaque no topo da página).
"""
import html
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'content' / 'ajuda'
DOCS = ROOT / 'docs'
OUT = DOCS / 'ajuda'
SITE = 'https://carburante.motorcycles'
STORE = 'https://apps.apple.com/br/app/carburante/id6785659437'
APP = 'Carburante 1.1 para iPhone'
CONTACT = 'contato@wagnerrosa.com'
SECTIONS = ['Primeiros passos', 'Consumo', 'Abastecimentos', 'Manutenção', 'Garagem e Premium', 'Conta e dados']
MONTHS = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto',
          'setembro', 'outubro', 'novembro', 'dezembro']
CSS_V = re.search(r'style\.css\?v=(\d+)', (DOCS / 'index.html').read_text()).group(1)


def pt_date(iso):
    y, m, d = iso.split('-')
    return f'{int(d)} de {MONTHS[int(m) - 1]} de {y}'


def load(path):
    text = path.read_text(encoding='utf-8')
    _, fm, body = text.split('---\n', 2)
    meta = {}
    for line in fm.strip().splitlines():
        k, v = line.split(':', 1)
        meta[k.strip()] = v.strip()
    meta['order'] = int(meta.get('order', 99))
    meta['related'] = [s.strip() for s in meta.get('related', '').split(',') if s.strip()]
    meta['body'] = body.strip()
    meta['url'] = f'{SITE}/ajuda/{meta["slug"]}/'
    assert meta['section'] in SECTIONS, (path.name, meta['section'])
    assert len(meta['description']) <= 165, (path.name, len(meta['description']))
    return meta


# ---------- Markdown pequeno → HTML ----------

def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', s)

    def link(m):
        text, url = m.group(1), m.group(2)
        ext = url.startswith('http') or url.startswith('mailto:')
        attrs = ' target="_blank" rel="noopener"' if url.startswith('http') else ''
        if url.startswith(STORE):
            attrs = ' class="js-store"' + attrs
        return f'<a href="{html.escape(url)}"{attrs}>{text}</a>' if ext or url.startswith('/') else m.group(0)
    return re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)', link, s)


def slugify(s):
    s = s.lower()
    for a, b in zip('áàâãéêíóôõúç', 'aaaaeeiooouc'):
        s = s.replace(a, b)
    return re.sub(r'[^a-z0-9]+', '-', s).strip('-')


def blocks(md):
    out, cur = [], []
    for line in md.splitlines():
        if line.strip() == '':
            if cur:
                out.append(cur)
                cur = []
        else:
            cur.append(line)
    if cur:
        out.append(cur)
    return out


def render(md):
    parts, first_p = [], True
    for b in blocks(md):
        head = b[0]
        if head.startswith('### '):
            t = head[4:]
            parts.append(f'<h3 id="{slugify(t)}">{inline(t)}</h3>')
            rest = b[1:]
        elif head.startswith('## '):
            t = head[3:]
            parts.append(f'<h2 id="{slugify(t)}">{inline(t)}</h2>')
            rest = b[1:]
        else:
            rest = b
        if not rest:
            continue
        if all(l.startswith('- ') for l in rest):
            parts.append('<ul>' + ''.join(f'<li>{inline(l[2:])}</li>' for l in rest) + '</ul>')
        elif all(re.match(r'\d+\. ', l) for l in rest):
            items = [inline(re.sub(r'^\d+\. ', '', l)) for l in rest]
            parts.append('<ol>' + ''.join(f'<li>{t}</li>' for t in items) + '</ol>')
        elif all(l.startswith('>') for l in rest):
            parts.append('<aside class="help__note">' + inline(' '.join(l.lstrip('> ').strip() for l in rest)) + '</aside>')
        elif all(l.startswith('|') for l in rest):
            rows = [[c.strip() for c in l.strip('|').split('|')] for l in rest if not re.match(r'^\|[\s:|-]+\|$', l)]
            th = ''.join(f'<th scope="col">{inline(c)}</th>' for c in rows[0])
            tb = ''.join('<tr>' + ''.join(f'<td>{inline(c)}</td>' for c in r) + '</tr>' for r in rows[1:])
            parts.append(f'<div class="help__table"><table><thead><tr>{th}</tr></thead><tbody>{tb}</tbody></table></div>')
        else:
            cls = ' class="help__lead"' if first_p else ''
            parts.append(f'<p{cls}>{inline(" ".join(rest))}</p>')
            first_p = False
    return '\n'.join(parts)


def absolute(md):
    """Links internos viram absolutos (llms-full.txt é lido fora do site)."""
    return re.sub(r'\]\((/[^)]*)\)', lambda m: f']({SITE}{m.group(1)})', md)


# ---------- Moldura das páginas ----------

ANALYTICS = """  <!-- Mesmo GA4 + Clarity da landing. Desligado em localhost, com localStorage.dev_mode = 'true' ou ?preview=dev. -->
  <script>
    (function () {
      var h = location.hostname;
      var off = h === 'localhost' || h === '127.0.0.1' || h === '';
      try {
        if (/[?&]preview=dev\\b/.test(location.search)) sessionStorage.setItem('dev_preview', 'true');
        off = off || localStorage.getItem('dev_mode') === 'true' || sessionStorage.getItem('dev_preview') === 'true';
      } catch (e) { /* storage bloqueado */ }
      if (off) return;
      var s = document.createElement('script');
      s.async = true;
      s.src = 'https://www.googletagmanager.com/gtag/js?id=G-JNKWNRL5KE';
      document.head.appendChild(s);
      window.dataLayer = window.dataLayer || [];
      window.gtag = function () { dataLayer.push(arguments); };
      gtag('js', new Date());
      gtag('config', 'G-JNKWNRL5KE');
      (function (c, l, a, r, i, t, y) {
        c[a] = c[a] || function () { (c[a].q = c[a].q || []).push(arguments); };
        t = l.createElement(r); t.async = 1; t.src = 'https://www.clarity.ms/tag/' + i;
        y = l.getElementsByTagName(r)[0]; y.parentNode.insertBefore(t, y);
      })(window, document, 'clarity', 'script', 'vhbu1gthme');
    })();
  </script>"""

TRACK = """<script>
  // Clique para a App Store = generate_lead (mesmo evento da landing)
  document.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('a.js-store') : null;
    if (a && typeof window.gtag === 'function') window.gtag('event', 'generate_lead', { method: 'app_store', event_location: 'help' });
  });
</script>"""

ORG = {'@type': 'Organization', '@id': f'{SITE}/#org', 'name': 'Carburante', 'url': f'{SITE}/',
       'logo': f'{SITE}/assets/icon-256.png'}
AUTHOR = {'@type': 'Person', 'name': 'Wagner Rosa', 'url': 'https://wagnerrosa.com'}


def jsonld(graph):
    body = json.dumps({'@context': 'https://schema.org', '@graph': graph}, ensure_ascii=False, indent=2)
    return '  <script type="application/ld+json">\n' + '\n'.join('  ' + l for l in body.split('\n')) + '\n  </script>'


def page(title, description, url, main, ld):
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <meta name="description" content="{html.escape(description)}">
  <link rel="canonical" href="{url}">
  <meta name="author" content="Wagner Rosa">
  <meta name="theme-color" content="#050505">
  <meta name="color-scheme" content="dark">
  <meta name="robots" content="index,follow">
  <meta name="apple-itunes-app" content="app-id=6785659437">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="Carburante">
  <meta property="og:title" content="{html.escape(title)}">
  <meta property="og:description" content="{html.escape(description)}">
  <meta property="og:url" content="{url}">
  <meta property="og:image" content="{SITE}/assets/og.png?v=5">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="icon" type="image/png" href="/assets/favicon.png">
  <link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
  <link rel="stylesheet" href="/style.css?v={CSS_V}">
{jsonld(ld)}

{ANALYTICS}
</head>
<body>

<!-- Gerado por scripts/build-ajuda.py a partir de content/ajuda/. Edite o .md, não este arquivo. -->
<a class="skip" href="#main">Pular para o conteúdo</a>

<header class="nav" id="top">
  <div class="wrap nav__inner">
    <a class="brand" href="/" aria-label="Carburante — página inicial">
      <img src="/assets/icon-256.png" alt="" width="30" height="30">
      <span>Carburante</span>
    </a>
    <a class="help__navlink" href="/ajuda/">Ajuda</a>
    <div class="nav__actions">
      <a class="btn btn--flame btn--nav js-store" href="{STORE}" target="_blank" rel="noopener">Baixar grátis</a>
    </div>
  </div>
</header>

<main id="main" class="legal help">
  <div class="wrap wrap--narrow">
{main}
  </div>
</main>

<footer class="footer">
  <div class="wrap footer__inner">
    <a class="brand" href="/">
      <img src="/assets/icon-256.png" alt="" width="26" height="26" loading="lazy">
      <span>Carburante</span>
    </a>
    <p class="footer__by">Wagner Rosa · 2026</p>
    <nav class="footer__links" aria-label="Links">
      <a href="/">Carburante</a>
      <a href="/ajuda/">Ajuda</a>
      <a href="/privacidade/">Privacidade</a>
      <a href="https://www.instagram.com/carburante.app/" target="_blank" rel="noopener">Instagram</a>
      <a href="https://www.reddit.com/r/carburante/" target="_blank" rel="noopener">Reddit</a>
      <a href="mailto:{CONTACT}">Email</a>
    </nav>
  </div>
</footer>

{TRACK}
</body>
</html>
"""


def article_html(a, by_slug):
    rel = [by_slug[s] for s in a['related']]
    related = ''
    if rel:
        items = ''.join(f'<li><a href="/ajuda/{r["slug"]}/">{html.escape(r["title"])}</a></li>' for r in rel)
        related = f'\n      <aside class="help__related" aria-labelledby="veja-tambem"><h2 id="veja-tambem">Veja também</h2><ul>{items}</ul></aside>'
    main = f"""    <nav class="help__crumbs" aria-label="Você está em"><a href="/ajuda/">Ajuda</a> <span aria-hidden="true">›</span> {html.escape(a['section'])}</nav>
    <article>
      <h1>{html.escape(a['title'])}</h1>
      <p class="legal__updated">Atualizado em {pt_date(a['updated'])} · {APP}</p>
{render(a['body'])}{related}
      <div class="help__contact">
        <p>Não achou o que procurava? Escreva para <a href="mailto:{CONTACT}">{CONTACT}</a>.</p>
        <a class="btn btn--flame js-store" href="{STORE}" target="_blank" rel="noopener">Baixar o Carburante grátis</a>
      </div>
    </article>"""
    ld = [
        ORG,
        {'@type': 'TechArticle', '@id': a['url'] + '#article', 'headline': a['title'], 'description': a['description'],
         'inLanguage': 'pt-BR', 'datePublished': a.get('published', a['updated']), 'dateModified': a['updated'],
         'author': AUTHOR, 'publisher': {'@id': f'{SITE}/#org'}, 'mainEntityOfPage': a['url'],
         'isPartOf': {'@id': f'{SITE}/ajuda/#collection'},
         'about': {'@type': 'MobileApplication', 'name': 'Carburante', 'operatingSystem': 'iOS', 'installUrl': STORE}},
        {'@type': 'BreadcrumbList', 'itemListElement': [
            {'@type': 'ListItem', 'position': 1, 'name': 'Carburante', 'item': f'{SITE}/'},
            {'@type': 'ListItem', 'position': 2, 'name': 'Ajuda', 'item': f'{SITE}/ajuda/'},
            {'@type': 'ListItem', 'position': 3, 'name': a['title'], 'item': a['url']}]},
    ]
    return page(f'{a["title"]} · Ajuda do Carburante', a['description'], a['url'], main, ld)


INDEX_TITLE = 'Ajuda do Carburante'
INDEX_DESC = 'Manual do Carburante: como registrar abastecimentos, como o consumo da moto é calculado, manutenção, garagem, Premium e conta. Uma pergunta por página.'


def index_html(arts):
    groups = []
    for sec in SECTIONS:
        items = [a for a in arts if a['section'] == sec]
        if not items:
            continue
        lis = ''.join(f'<li><a href="/ajuda/{a["slug"]}/"><strong>{html.escape(a["title"])}</strong>'
                      f'<span>{html.escape(a["description"])}</span></a></li>' for a in items)
        groups.append(f'      <section class="help__group" aria-labelledby="{slugify(sec)}"><h2 id="{slugify(sec)}">{html.escape(sec)}</h2><ul>{lis}</ul></section>')
    updated = max(a['updated'] for a in arts)
    main = f"""    <article class="help__index">
      <h1>{INDEX_TITLE}</h1>
      <p class="help__lead">Respostas diretas para as dúvidas mais comuns, uma pergunta por página. Vale para o {APP}.</p>
      <p class="legal__updated">Atualizado em {pt_date(updated)}</p>
{chr(10).join(groups)}
      <div class="help__contact">
        <p>Não achou o que procurava? Veja as <a href="/#faq">perguntas frequentes</a> ou escreva para <a href="mailto:{CONTACT}">{CONTACT}</a>.</p>
      </div>
    </article>"""
    ld = [
        ORG,
        {'@type': 'CollectionPage', '@id': f'{SITE}/ajuda/#collection', 'name': INDEX_TITLE, 'description': INDEX_DESC,
         'url': f'{SITE}/ajuda/', 'inLanguage': 'pt-BR', 'dateModified': updated, 'publisher': {'@id': f'{SITE}/#org'},
         'hasPart': [{'@id': a['url'] + '#article'} for a in arts]},
        {'@type': 'BreadcrumbList', 'itemListElement': [
            {'@type': 'ListItem', 'position': 1, 'name': 'Carburante', 'item': f'{SITE}/'},
            {'@type': 'ListItem', 'position': 2, 'name': 'Ajuda', 'item': f'{SITE}/ajuda/'}]},
    ]
    return page(INDEX_TITLE, INDEX_DESC, f'{SITE}/ajuda/', main, ld), updated


def replace_between(text, start, end, new, before):
    if start in text:
        a, b = text.index(start), text.index(end) + len(end)
        return text[:a] + new + text[b:]
    i = text.index(before)
    return text[:i] + new + '\n' + ('\n' if before.startswith('#') else '') + text[i:]


def main():
    arts = sorted((load(p) for p in SRC.glob('*.md')), key=lambda a: (SECTIONS.index(a['section']), a['order']))
    by_slug = {a['slug']: a for a in arts}
    for a in arts:
        for r in a['related']:
            assert r in by_slug, (a['slug'], r)
    # páginas (apaga as que sumiram do content/)
    keep = {a['slug'] for a in arts}
    for d in OUT.glob('*/'):
        if d.is_dir() and d.name not in keep and (d / 'index.html').exists():
            (d / 'index.html').unlink()
            d.rmdir()
    for a in arts:
        (OUT / a['slug']).mkdir(parents=True, exist_ok=True)
        (OUT / a['slug'] / 'index.html').write_text(article_html(a, by_slug), encoding='utf-8')
    idx, updated = index_html(arts)
    (OUT / 'index.html').write_text(idx, encoding='utf-8')

    # llms.txt: seção Manual
    lines = ['<!-- ajuda:start -->', '## Manual (Ajuda)', '',
             f'Passo a passo do app, uma pergunta por página: {SITE}/ajuda/ — texto completo num arquivo só: {SITE}/llms-full.txt', '']
    lines += [f'- [{a["title"]}]({a["url"]}): {a["description"]}' for a in arts]
    lines += ['<!-- ajuda:end -->']
    llms = DOCS / 'llms.txt'
    llms.write_text(replace_between(llms.read_text(encoding='utf-8'), '<!-- ajuda:start -->', '<!-- ajuda:end -->',
                                    '\n'.join(lines), '## Perguntas frequentes'), encoding='utf-8')

    # llms-full.txt: o manual inteiro
    full = [f'# Carburante — manual completo', '',
            f'> App grátis para iPhone que registra os abastecimentos da moto e mostra o consumo real (km/l), de tanque cheio a tanque cheio. '
            f'Este arquivo reúne todas as páginas da Ajuda ({SITE}/ajuda/). Vale para o {APP}. Atualizado em {pt_date(updated)}.', '',
            f'- Site: {SITE}/', f'- App Store: {STORE}', f'- Contato: {CONTACT}', '']
    for a in arts:
        full += ['---', '', f'# {a["title"]}', '', f'Fonte: {a["url"]} · Seção: {a["section"]} · Atualizado em {pt_date(a["updated"])}', '',
                 absolute(a['body']), '']
    (DOCS / 'llms-full.txt').write_text('\n'.join(full), encoding='utf-8')

    # sitemap.xml
    urls = [f'  <url>\n    <loc>{SITE}/ajuda/</loc>\n    <lastmod>{updated}</lastmod>\n  </url>']
    urls += [f'  <url>\n    <loc>{a["url"]}</loc>\n    <lastmod>{a["updated"]}</lastmod>\n  </url>' for a in arts]
    sm = DOCS / 'sitemap.xml'
    block = '  <!-- ajuda:start -->\n' + '\n'.join(urls) + '\n  <!-- ajuda:end -->'
    sm.write_text(replace_between(sm.read_text(encoding='utf-8'), '  <!-- ajuda:start -->', '<!-- ajuda:end -->', block, '</urlset>'),
                  encoding='utf-8')
    print(f'{len(arts)} páginas + índice · llms.txt, llms-full.txt, sitemap.xml atualizados')


if __name__ == '__main__':
    main()
