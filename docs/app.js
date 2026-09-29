// Carburante — landing page. i18n PT/EN, contador de estrelas, reveal on scroll.
(function () {
  'use strict';

  // O HTML já vem em pt-BR (SEO / sem JS). Só o inglês mora aqui; o português é
  // lido do próprio DOM na carga e restaurado ao voltar.
  var EN = {
    'skip': 'Skip to content',
    'nav.how': 'How it works',
    'nav.features': 'Features',
    'nav.roadmap': 'Roadmap',
    'hero.pill': 'TestFlight beta · iPhone',
    'hero.title': 'See your bike’s <span class="flame-text">real fuel economy.</span>',
    'hero.lede': 'Log the fuel-up at the pump, even with no signal. Carburante measures consumption from full tank to full tank and warns you before the next service is due.',
    'cta.beta': 'Join the beta',
    'cta.how': 'How it works',
    'hero.meta': 'Free during beta · iOS 18+ · Portuguese UI for now',
    'alt.hero': 'Carburante Summary screen: 28.8 km/l average, cost per km and monthly spend',
    'alt.fuel': 'Fuel-up review screen showing 29.6 km/l for this tank',
    'alt.consumption': 'Per-tank consumption chart with a 28.8 km/l average and category comparison',
    'alt.maintenance': 'Scheduled maintenance list showing how far each item is',
    'alt.garage': 'Garage with average consumption and cost plus the achievement level',
    'p1.t': 'Fuel up in seconds',
    'p1.d': 'Odometer, price and liters. The date fills itself in, and so does the place if you allow location. Fits in a gas-station stop.',
    'p2.t': 'Honest consumption',
    'p2.d': 'Measured from full tank to full tank, the method that doesn’t lie. No inflated averages.',
    'p3.t': 'No-surprise maintenance',
    'p3.d': 'Oil, tires, chain and brakes. The app warns you before they’re due, by distance or by date.',
    'm.kicker': 'How we measure',
    'm.title': 'Full tank to full tank. The method that doesn’t lie.',
    'm1.t': 'Fill it up',
    'm1.d': 'Your first full tank is the starting point. No average yet, and the app shows how many fuel-ups are left.',
    'm2.t': 'Ride as usual',
    'm2.d': 'Only topped up a bit? Switch off “Full tank”. Those liters still count toward the stretch.',
    'm3.t': 'Fill up again',
    'm3.d': 'Distance ridden ÷ liters added over the stretch. With a full tank at both ends, the math adds up.',
    'm.note': 'Dividing each fuel-up by the previous one looks simpler, but it’s wrong every time the tank isn’t full. That’s where inflated averages come from.',
    'f.kicker': 'Features',
    'f.title': 'Built for riding, not for typing.',
    'f1.k': 'Logging',
    'f1.t': 'Three steps. Zero wasted fields.',
    'f1.d': 'It remembers your last fuel type, works out the price per liter on the spot and shows that tank’s consumption before you save. Got the receipt? Tap Scan: it’s read right on your iPhone and the receipt photo isn’t kept.',
    'f2.k': 'Consumption',
    'f2.t': 'Twisties or traffic? The chart shows.',
    'f2.d': 'Tank-by-tank chart, period average and an estimated benchmark for your bike’s category and engine size, if you enter both.',
    'f3.k': 'Maintenance',
    'f3.t': 'Every part on its own schedule.',
    'f3.d': 'Set intervals by distance and by months. A bar shows what’s left and a notification arrives before it’s due. Every service stays on record with date, mileage and cost.',
    'f4.k': 'Garage',
    'f4.t': 'Your garage, every bike kept apart.',
    'f4.d': 'Track consumption and maintenance for each bike separately. Records and totals add up the whole garage.',
    'x1.t': 'Works offline',
    'x1.d': 'No signal at a roadside station? It saves on the device and syncs later.',
    'x2.t': 'Private by default',
    'x2.d': 'Photos are read on your iPhone. No ads, no selling your data.',
    'x3.t': 'No sign-up',
    'x3.d': 'Open it and go. No account to create, no password.',
    'x4.t': 'Gentle reminders',
    'x4.d': 'Nudges you about the oil change and reminds you to log if you go quiet.',
    'bt.title': 'Try it at your next fuel-up.',
    'bt.d': 'For people who ride often. Open the link on your iPhone, install TestFlight and you’re in. Requires iOS 18 or later; the app is in Portuguese for now. Limited spots.',
    'bt.mail': 'Questions or ideas? <a href="mailto:contato@wagnerrosa.com?subject=Carburante">contato@wagnerrosa.com</a>',
    'q.kicker': 'Questions',
    'q.title': 'Before you ask.',
    'q1.q': 'Is it free?',
    'q1.a': 'Yes, for the whole beta. The App Store model is still being defined, and beta testers will be the first to know.',
    'q2.q': 'Is there an Android version?',
    'q2.a': 'Not for now. Carburante is native to iPhone on purpose: fast, light and at home in the system.',
    'q3.q': 'Do I need an account?',
    'q3.a': 'No. Open it and go: the app works with no account to create and no password.',
    'q4.q': 'Where does my data live?',
    'q4.a': 'On your iPhone first, with a cloud copy isolated to your account. Usage stats are anonymous and can be turned off in Settings. Details in the <a href="privacidade/">privacy policy</a>.',
    'q7.q': 'What happens to my photos?',
    'q7.a': 'They’re read right on your iPhone. Receipt photos aren’t kept. The odometer photo stays as proof of the record: on your iPhone and in a private folder for your account in the cloud.',
    'q5.q': 'Why doesn’t consumption show on the first fuel-up?',
    'q5.a': 'Because honest consumption is measured between two full tanks: the first one is the starting point. The app tells you how many fuel-ups are left until your first average appears.',
    'q8.q': 'Can it read the pump display?',
    'q8.a': 'No. I tested it, and pump display photos can’t be read reliably. The app reads the printed receipt, where it works, and you check the values before saving.',
    'q6.q': 'Is the code open?',
    'q6.a': 'The code is public on GitHub for anyone curious about how the app is built. If you like it, leave a star, it helps a lot.',
    'b.kicker': 'Achievements',
    'b.title': 'Riding is collecting, too.',
    'b.lede': '25 badges weighted by difficulty and levels that actually mean something. Recognition only: no feature is ever locked behind a badge.',
    'bd.fuel': 'First fuel-up',
    'bd.maint': 'First service',
    'bd.best': 'Above average',
    'bd.cc': '500cc Club',
    'bd.iron': 'Iron Butt · later',
    'r.kicker': 'Roadmap',
    'r.title': 'Today, a logbook. On the horizon, your bike’s passport.',
    'r.quote': '“The bike carries its events. You keep your story.”',
    'r.lede': 'The idea is for the history to belong to the motorcycle, not the owner: in a sale, services, mileage and consumption would go with it. None of this has a date. What comes next depends on what the beta shows.',
    'st.done': 'Shipped',
    'st.now': 'Now',
    'st.planned': 'Planned',
    'st.vision': 'Vision',
    'st.ideas': 'Ideas',
    'r1.t': 'Logbook',
    'r1.d': 'Fast fuel logging, real consumption, receipt reading, scheduled maintenance, a multi-bike garage, badges and a cloud copy of your records.',
    'r1.link': 'See the features',
    'r2.t': 'TestFlight beta',
    'r2.d': 'Real riders using it day to day through TestFlight. This is where you come in: every fuel-up logged helps decide what comes next.',
    'r3.t': 'Digital passport',
    'r3.d': 'The history starts belonging to the bike, keeping the author of each record.',
    'r4.t': 'QR code transfer',
    'r4.d': 'Sold your bike? A code would hand over ownership and the history to the buyer.',
    'r5.t': 'A profile that stays with you',
    'r5.d': 'Your miles and badges would stay yours after a sale, bike documents (invoices, receipts, certificates) would be attached to it, and there’d be a way to check the history wasn’t altered.',
    'r6.t': 'Beyond the pump',
    'r6.d': 'Real consumption vs. factory figures, weather at each fuel-up, a ride diary and trips, long-distance challenges like the Iron Butt and, someday, community.',
    's.kicker': 'Behind the scenes',
    's.title': 'Made by someone who rides, too.',
    's.lede': 'I’m <a href="https://wagnerrosa.com" target="_blank" rel="noopener">Wagner Rosa</a>, product designer and rider for over two decades. I built Carburante for a simple reason: logging a fuel-up has to fit in a gas-station stop.',
    'alt.wagner': 'Wagner Rosa riding on a mountain road',
    's.portfolio': 'View portfolio',
    's.code': 'Read the code',
    'ft.by': 'Built with <span class="footer__moto" role="img" aria-label="scooter">🛵</span> by <a href="https://wagnerrosa.com" target="_blank" rel="noopener">Wagner Rosa</a>',
    'ft.copy': '© 2026 Carburante. All rights reserved.',
    'ft.portfolio': 'Portfolio',
    'ft.privacy': 'Privacy',
    'ft.legal': 'Motorcycle manufacturer names and logos shown in the screens are trademarks or registered trademarks of their respective owners, used only to identify the registered bike. Carburante is independent and is not affiliated with, sponsored or endorsed by any manufacturer.'
  };

  var META = {
    pt: {
      title: document.title,
      toggle: 'EN', toggleLabel: 'Switch to English', html: 'pt-BR'
    },
    en: {
      title: 'Carburante · Your bike’s real fuel economy',
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
  // espelham o site_interaction do portfólio (mesmo formato, propriedade GA4 própria); o pedido de beta
  // vai como generate_lead para ser marcado como key event.
  document.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    var box = a.closest('footer') ? { id: 'footer' } : a.closest('section[id], header[id]');
    var where = !box ? 'hero' : box.id === 'top' ? 'nav' : box.id;
    var href = a.getAttribute('href');
    if (a.classList.contains('js-beta')) {
      track('generate_lead', { method: 'testflight', event_location: where });
    } else if (href === '#consumo') {
      track('site_interaction', { event_category: 'navigation', event_label: 'anchor_how', event_location: where });
    } else if (/github\.com/.test(href)) {
      track('site_interaction', { event_category: 'outbound', event_label: 'outbound_github', event_location: where });
    } else if (/^https:\/\/wagnerrosa\.com\/?$/.test(href)) {
      track('site_interaction', { event_category: 'navigation', event_label: 'internal_portfolio', event_location: where });
    } else if (/^mailto:/.test(href)) {
      track('site_interaction', { event_category: 'outbound', event_label: 'outbound_email', event_location: where });
    }
  });

  // FAQ: o <details> nativo abre seco e o Safari não anima height: auto em CSS.
  // Anima a altura (Web Animations) e a resposta entra com fade. Sem suporte ou
  // com "reduzir movimento", fica o abre/fecha nativo.
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!reduceMotion && Element.prototype.animate) {
    var EASE = 'cubic-bezier(.32, .72, 0, 1)';
    document.querySelectorAll('.faq details').forEach(function (d) {
      var summary = d.querySelector('summary');
      var answer = d.querySelector('p');
      var anim = null, fade = null;
      summary.addEventListener('click', function (e) {
        e.preventDefault();
        var opening = !d.open || d.classList.contains('is-closing');
        var start = d.offsetHeight; // altura atual, mesmo no meio de outra animação
        if (anim) anim.cancel();
        if (fade) fade.cancel();
        d.classList.remove('is-closing');
        d.style.overflow = 'hidden';
        if (opening) {
          d.open = true;
          anim = d.animate({ height: [start + 'px', d.offsetHeight + 'px'] }, { duration: 380, easing: EASE });
          if (answer) fade = answer.animate({ opacity: [0, 1], transform: ['translateY(-6px)', 'none'] }, { duration: 380, easing: EASE });
        } else {
          d.classList.add('is-closing');
          anim = d.animate({ height: [start + 'px', summary.offsetHeight + 'px'] }, { duration: 260, easing: EASE });
          if (answer) fade = answer.animate({ opacity: [1, 0] }, { duration: 180, easing: 'ease-out', fill: 'forwards' });
        }
        anim.onfinish = function () {
          if (d.classList.contains('is-closing')) { d.open = false; d.classList.remove('is-closing'); }
          if (fade) { fade.cancel(); fade = null; }
          d.style.overflow = '';
          anim = null;
        };
      });
    });
  }

  // Bastidores: a foto vira a versão 3D a partir do farol (efeito todo no CSS).
  // Mouse: hover revela e o cartão inclina com o cursor; parado na tela, o farol
  // pisca de tempos em tempos mostrando uma fresta do 3D. Toque (sem hover): revela
  // sozinho quando o cartão chega ao meio da tela; tocar alterna.
  var rider = document.querySelector('[data-rider]');
  if (rider) {
    var stage = rider.querySelector('.story__stage');
    var fine = window.matchMedia && window.matchMedia('(hover: hover) and (pointer: fine)').matches;
    var riderOn = false, riderSeen = false, peekTimer = null, peeks = 0, tilt = 0;

    var setRider = function (on) {
      if (on === riderOn) return;
      riderOn = on;
      rider.classList.remove('is-peek');
      rider.classList.toggle('is-on', on);
      if (on && !riderSeen) {
        riderSeen = true;
        track('site_interaction', { event_category: 'ui', event_label: 'story_3d', event_location: 'bastidores' });
      }
    };
    var stopPeeks = function () { clearTimeout(peekTimer); peekTimer = null; };
    var peek = function () {
      if (riderOn || peeks >= 4) return stopPeeks();
      peeks++;
      rider.classList.remove('is-peek');
      void rider.offsetWidth; // reinicia a animação
      rider.classList.add('is-peek');
      peekTimer = setTimeout(peek, 6500);
    };
    rider.addEventListener('animationend', function (e) {
      if (e.animationName === 'rider-peek') rider.classList.remove('is-peek');
    });

    if (fine) {
      rider.addEventListener('pointerenter', function () { stopPeeks(); setRider(true); });
      rider.addEventListener('pointerleave', function () {
        cancelAnimationFrame(tilt);
        stage.style.removeProperty('--tx');
        stage.style.removeProperty('--ty');
        setRider(false);
      });
      if (!reduceMotion) {
        rider.addEventListener('pointermove', function (e) {
          cancelAnimationFrame(tilt);
          tilt = requestAnimationFrame(function () {
            var b = rider.getBoundingClientRect();
            stage.style.setProperty('--tx', ((e.clientX - b.left) / b.width * 2 - 1).toFixed(3));
            stage.style.setProperty('--ty', ((e.clientY - b.top) / b.height * 2 - 1).toFixed(3));
          });
        });
      }
    } else {
      rider.addEventListener('click', function () { setRider(!riderOn); });
    }

    if (!reduceMotion && 'IntersectionObserver' in window) {
      var autoTimer = null, visible = false;
      new IntersectionObserver(function (entries) {
        var r = entries[0].intersectionRatio;
        if (fine) {
          // Fresta: primeira piscada logo depois de entrar na tela, no máximo 4 por visita.
          if (r >= 0.5 && !visible) { peeks = 0; stopPeeks(); peekTimer = setTimeout(peek, 1200); }
          else if (r < 0.5) stopPeeks();
          visible = r >= 0.5;
        } else {
          clearTimeout(autoTimer);
          if (r >= 0.7) autoTimer = setTimeout(function () { setRider(true); }, 700);
          else if (r < 0.3) setRider(false);
        }
      }, { threshold: [0, 0.3, 0.5, 0.7] }).observe(rider);
    }
  }

  // Recursos no celular = carrossel (scroll-snap no CSS); os pontos só acompanham a posição.
  // (não chamar de "track": o var sobrescreveria a função de analytics do mesmo escopo)
  var rail = document.querySelector('.features');
  var dots = document.querySelectorAll('.features__dots span');
  if (rail && dots.length) {
    var dotFrame = 0;
    rail.addEventListener('scroll', function () {
      cancelAnimationFrame(dotFrame);
      dotFrame = requestAnimationFrame(function () {
        var slides = rail.children;
        var step = slides[1].offsetLeft - slides[0].offsetLeft;
        var atEnd = rail.scrollLeft >= rail.scrollWidth - rail.clientWidth - 2;
        var i = atEnd ? slides.length - 1 : Math.round(rail.scrollLeft / step);
        dots.forEach(function (el, k) { el.classList.toggle('is-on', k === i); });
      });
    }, { passive: true });
  }

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
