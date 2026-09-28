// Carburante — landing page. i18n PT/EN, contador de estrelas, reveal on scroll.
(function () {
  'use strict';

  // O HTML já vem em pt-BR (SEO / sem JS). Só o inglês mora aqui; o português é
  // lido do próprio DOM na carga e restaurado ao voltar.
  var EN = {
    'skip': 'Skip to content',
    'nav.features': 'Features',
    'nav.roadmap': 'Roadmap',
    'nav.story': 'Story',
    'nav.beta': 'Beta',
    'hero.pill': 'Open beta · iPhone',
    'hero.title': 'The logbook <span class="flame-text">for your motorcycle.</span>',
    'hero.lede': 'Log fuel-ups in seconds, learn what your bike really does per liter and never miss an oil change again. Native to iPhone, works even with no signal.',
    'cta.beta': 'Join the beta',
    'cta.github': 'View on GitHub',
    'cta.join': 'Join the beta',
    'hero.meta': 'Free during beta · iOS 18+ · Portuguese UI for now',
    'alt.hero': 'Carburante Summary screen: 28.8 km/l average, cost per km and monthly spend',
    'alt.fuel': 'Fuel-up review screen showing 29.6 km/l for this tank',
    'alt.consumption': 'Per-tank consumption chart with a 28.8 km/l average and category comparison',
    'alt.maintenance': 'Scheduled maintenance list showing how far each item is',
    'alt.garage': 'Garage with level 4 and a grid of earned badges',
    'p1.t': 'Fuel up in seconds',
    'p1.d': 'Odometer, price and liters. Date and place fill themselves in. Fits in a gas-station stop.',
    'p2.t': 'Honest consumption',
    'p2.d': 'Measured from full tank to full tank, the method that doesn’t lie. No inflated averages.',
    'p3.t': 'No-surprise maintenance',
    'p3.d': 'Oil, tires, chain and brakes. The app warns you before they’re due, by distance or by date.',
    'f.kicker': 'Features',
    'f.title': 'Built for riding, not for typing.',
    'f1.k': 'Logging',
    'f1.t': 'Three steps. Zero wasted fields.',
    'f1.d': 'It remembers your last fuel type, works out the price per liter on the spot and shows that tank’s consumption before you save. Got the receipt? Tap Scan: the photo is read on your iPhone and never leaves it.',
    'f2.k': 'Consumption',
    'f2.t': 'Know your bike as it really is.',
    'f2.d': 'Tank-by-tank chart, period average and a comparison with bikes of the same category. Find out whether that mountain ride beat the weekday traffic.',
    'f3.k': 'Maintenance',
    'f3.t': 'Every part on its own schedule.',
    'f3.d': 'Set intervals by distance and by months. A bar shows what’s left and a notification arrives before it’s due. The history is kept, ready to show whoever buys your bike.',
    'f4.k': 'Garage',
    'f4.t': 'All your bikes, each in its own color.',
    'f4.d': 'The app takes on the brand color of your active bike. Records, lifetime totals and a level that grows as you ride.',
    'x1.t': 'Works offline',
    'x1.d': 'No signal at a roadside station? It saves on the device and syncs later.',
    'x2.t': 'Private by default',
    'x2.d': 'Receipt photos are read on your iPhone. Your data doesn’t become ads.',
    'x3.t': 'No sign-up',
    'x3.d': 'Open it and go. Sign in with Apple only if you want your data on another device.',
    'x4.t': 'Gentle reminders',
    'x4.d': 'Nudges you about the oil change and reminds you to log if you go quiet.',
    'b.kicker': 'Achievements',
    'b.title': 'Riding is collecting, too.',
    'b.lede': '25 badges weighted by difficulty and levels that actually mean something. Recognition only: no feature is ever locked behind a badge.',
    'bd.fuel': 'First fuel-up',
    'bd.maint': 'First service',
    'bd.best': 'Above average',
    'bd.cc': '500cc Club',
    'bd.iron': 'Iron Butt · soon',
    'r.kicker': 'Roadmap',
    'r.title': 'Today, a logbook. Tomorrow, your bike’s passport.',
    'r.quote': '“The bike carries its events. You keep your story.”',
    'r.lede': 'The plan is for the history to belong to the motorcycle, not the owner. When it’s sold, services, mileage and consumption go with it, and a trustworthy history is worth real money on the used market.',
    'st.done': 'Shipped',
    'st.now': 'Now',
    'st.next': 'Next',
    'st.planned': 'Planned',
    'st.later': 'Later',
    'r1.t': 'Logbook',
    'r1.d': 'Fast fuel logging, real consumption, receipt reading, scheduled maintenance, a multi-bike garage, badges and sync with your Apple account.',
    'r2.t': 'Open beta',
    'r2.d': 'Real riders using it day to day through TestFlight. This is where you come in: every fuel-up logged helps decide what comes next.',
    'r3.t': 'Digital passport',
    'r3.d': 'The history starts belonging to the bike. Every record keeps who made it, forever.',
    'r4.t': 'QR code transfer',
    'r4.d': 'Sold your bike? A code hands over ownership and the buyer gets the full history.',
    'r5.t': 'A profile that stays with you',
    'r5.d': 'Your miles and badges stay yours after a sale. Bike documents (invoices, receipts, certificates) attached to it. And proof that the history wasn’t tampered with.',
    'r6.t': 'Beyond the pump',
    'r6.d': 'Real consumption vs. factory figures, weather at each fuel-up, a ride diary and trips, long-distance challenges like the Iron Butt and, someday, community.',
    's.kicker': 'Behind the scenes',
    's.title': 'A product project, from problem to TestFlight.',
    's.lede': 'Carburante is a personal project by <a href="https://wagnerrosa.com" target="_blank" rel="noopener">Wagner Rosa</a>, Senior Product Designer. Research, product definition, interface design and the native Swift app, end to end.',
    's.st1': 'reviewed pull requests',
    's.st2': 'automated tests',
    's.st3': 'third-party UI libraries',
    's.st4': 'usable without internet',
    'd1.t': 'Fewer taps, not more screens',
    'd1.d': 'Logging a fuel-up has to fit in a gas-station stop. Every new field had to earn its place.',
    'd2.t': 'Offline first',
    'd2.d': 'Roadside stations have no signal. Everything saves on the device and syncs when it can, without losing an edit.',
    'd3.t': 'Don’t promise the impossible',
    'd3.d': 'I tested reading the pump display from a photo: it isn’t reliable. The app reads the printed receipt, where it works, and leaves the rest to a quick review.',
    'd4.t': 'Metric before features',
    'd4.d': 'MVP success means riders coming back to log more than three fuel-ups. Social, rankings and the passport wait for that answer.',
    's.portfolio': 'View portfolio',
    's.code': 'Read the code',
    'bt.title': 'Try Carburante before everyone else.',
    'bt.d': 'You’ll need an iPhone on iOS 18 or later. Send me an email and I’ll send you a TestFlight invite, Apple’s official app for beta versions. The app is in Portuguese for now.',
    'bt.cta': 'Request an invite by email',
    'q.kicker': 'Questions',
    'q.title': 'Before you ask.',
    'q1.q': 'Is it free?',
    'q1.a': 'Yes, for the whole beta. The App Store model is still being defined, and beta testers will be the first to know.',
    'q2.q': 'Is there an Android version?',
    'q2.a': 'Not for now. Carburante is native to iPhone on purpose: fast, light and at home in the system.',
    'q3.q': 'Do I need an account?',
    'q3.a': 'No. Open it and go. If you want your data on another device, sign in with Apple and everything you logged stays there.',
    'q4.q': 'Where does my data live?',
    'q4.a': 'On your iPhone first. A copy lives in the cloud, isolated to your account, so you never lose anything. Receipt photos are read on the device and never uploaded. Usage stats are anonymous and can be turned off in Settings.',
    'q5.q': 'Why doesn’t consumption show on the first fuel-up?',
    'q5.a': 'Because honest consumption is measured between two full tanks: the first one is the starting point. The app tells you how many fuel-ups are left until your first average appears.',
    'q6.q': 'Is the code open?',
    'q6.a': 'The code is public on GitHub for anyone curious about how the app is built. If you like it, leave a star, it helps a lot.',
    'ft.by': 'Made by <a href="https://wagnerrosa.com" target="_blank" rel="noopener">Wagner Rosa</a> · 2026',
    'ft.portfolio': 'Portfolio'
  };

  var META = {
    pt: {
      title: document.title,
      mail: 'mailto:contato@wagnerrosa.com?subject=Beta%20Carburante&body=' +
        encodeURIComponent('Oi Wagner! Quero testar o Carburante.\n\nEmail da minha conta Apple (para o TestFlight): \nModelo do iPhone: \nMinha moto: '),
      toggle: 'EN', toggleLabel: 'Switch to English', html: 'pt-BR'
    },
    en: {
      title: 'Carburante · The logbook for your motorcycle',
      mail: 'mailto:contato@wagnerrosa.com?subject=Carburante%20beta&body=' +
        encodeURIComponent('Hi Wagner! I’d like to try Carburante.\n\nMy Apple account email (for TestFlight): \niPhone model: \nMy bike: '),
      toggle: 'PT', toggleLabel: 'Mudar para português', html: 'en'
    }
  };

  var nodes = Array.prototype.slice.call(document.querySelectorAll('[data-i18n]'));
  var altNodes = Array.prototype.slice.call(document.querySelectorAll('[data-i18n-alt]'));
  nodes.forEach(function (el) { el.dataset.pt = el.innerHTML; });
  altNodes.forEach(function (el) { el.dataset.ptAlt = el.getAttribute('alt'); });

  var toggle = document.getElementById('lang-toggle');
  var current = 'pt';

  function store(lang) { try { localStorage.setItem('carburante-lang', lang); } catch (e) { /* storage bloqueado */ } }
  function stored() { try { return localStorage.getItem('carburante-lang'); } catch (e) { return null; } }
  function track(name, params) { if (typeof window.gtag === 'function') window.gtag('event', name, params); }

  function apply(lang) {
    current = lang;
    var en = lang === 'en';
    nodes.forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      el.innerHTML = en && EN[key] ? EN[key] : el.dataset.pt;
    });
    altNodes.forEach(function (el) {
      var key = el.getAttribute('data-i18n-alt');
      el.setAttribute('alt', en && EN[key] ? EN[key] : el.dataset.ptAlt);
    });
    var m = META[lang];
    document.documentElement.lang = m.html;
    document.title = m.title;
    toggle.textContent = m.toggle;
    toggle.setAttribute('aria-label', m.toggleLabel);
    document.querySelectorAll('.js-beta').forEach(function (a) { a.href = m.mail; });
  }

  toggle.addEventListener('click', function () {
    var next = current === 'pt' ? 'en' : 'pt';
    apply(next);
    store(next);
    track('site_interaction', { event_category: 'ui', event_label: 'lang_' + next, event_location: 'nav' });
  });

  // Prioridade: ?lang=en|pt (link compartilhável) > escolha salva > idioma do navegador.
  var param = (location.search.match(/[?&]lang=(pt|en)\b/) || [])[1];
  var saved = stored();
  var nav = (navigator.language || 'pt').toLowerCase();
  apply(param || (saved === 'en' || saved === 'pt' ? saved : (nav.indexOf('pt') === 0 ? 'pt' : 'en')));

  // Estrelas do GitHub — contagem ao vivo; qualquer falha deixa o botão sem número.
  var count = document.getElementById('star-count');
  if (window.fetch && count) {
    fetch('https://api.github.com/repos/wagnerrosa/carburante', { headers: { Accept: 'application/vnd.github+json' } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (d && typeof d.stargazers_count === 'number' && d.stargazers_count > 0) {
          count.textContent = d.stargazers_count.toLocaleString();
          count.hidden = false;
        }
      })
      .catch(function () {});
  }

  // Analytics — cliques classificados pelo href, sem data-track no HTML: o i18n troca o
  // innerHTML dos parágrafos, e links internos a eles perderiam atributos. Parâmetros
  // espelham o site_interaction do portfólio (mesma propriedade GA4); o pedido de beta
  // vai como generate_lead para ser marcado como key event.
  document.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    var box = a.closest('footer') ? { id: 'footer' } : a.closest('section[id], header[id]');
    var where = !box ? 'hero' : box.id === 'top' ? 'nav' : box.id;
    var href = a.getAttribute('href');
    if (a.classList.contains('js-beta')) {
      track('generate_lead', { method: 'email', event_location: where });
    } else if (/github\.com/.test(href)) {
      track('site_interaction', { event_category: 'outbound', event_label: 'outbound_github', event_location: where });
    } else if (/^https:\/\/wagnerrosa\.com\/?$/.test(href)) {
      track('site_interaction', { event_category: 'navigation', event_label: 'internal_portfolio', event_location: where });
    } else if (/^mailto:/.test(href)) {
      track('site_interaction', { event_category: 'outbound', event_label: 'outbound_email', event_location: where });
    }
  });

  // Reveal on scroll.
  var items = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window)) {
    items.forEach(function (el) { el.classList.add('in'); });
    return;
  }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
  items.forEach(function (el) { io.observe(el); });
})();
