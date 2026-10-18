// Carburante — landing page. i18n PT/EN, seções presas à rolagem, reveal on scroll.
(function () {
  'use strict';

  // O HTML já vem em pt-BR (SEO / sem JS). Só o inglês mora aqui; o português é
  // lido do próprio DOM na carga e restaurado ao voltar.
  var EN = {
    'skip': 'Skip to content',
    'hero.title': 'Your bike’s fuel economy. <em class="accent flame-text">For real.</em>',
    'hero.lede': 'Log a fuel-up in seconds, even with no signal. We handle the rest: the right average and a heads-up before your next service.',
    'cta.store': 'Download on the App Store',
    'cta.badge': '<img src="assets/store/app-store-en-us.svg" alt="Download on the App Store" width="144" height="48">',
    'cta.nav': 'Download',
    'cta.how': 'How it works',
    'hero.meta': 'Free · iOS 18+ · Brazil only, Portuguese UI for now',
    'alt.hero': 'Carburante Summary screen with a Harley-Davidson: 20.3 km/l average, cost per km and monthly spend. The app switches bikes and changes color.',
    'alt.fuel': 'Logging a fuel-up: the odometer photo is read (22,039 km), the pump photo brings cost and liters (R$ 28.49 and 4.135 L) and the review shows 20.1 km/l for this tank',
    'alt.consumption': 'Tank-by-tank consumption chart for the Harley-Davidson, with a 20.3 km/l average and a category comparison',
    'alt.maintenance': 'An oil change notification arrives on the iPhone and opens the scheduled maintenance list',
    'alt.garage': 'Garage with three bikes, records, totals and the achievement level',
    'br.text': 'Less time at the pump. <em class="accent">More time on the road.</em>',
    'm.kicker': 'How we measure',
    'm.title': 'Full tank to full tank. <em class="accent">The math that doesn’t lie.</em>',
    'alt.cluster': 'Bike dashboard: the odometer goes from 22,039 to 22,391 km, 6.0 L go in on a partial fill-up and 11.3 L on the next full tank. 352 km ÷ 17.3 L = 20.3 km/l.',
    'ev1': 'Full tank · starting point',
    'ev2': '+6.0 L · partial',
    'ev3': '+11.3 L · full tank',
    'avg.label': 'Stretch average',
    'avg.math': '352 km ÷ 17.3 L',
    'avg.n': '20.3',
    'm1.t': 'Fill up.',
    'm1.d': 'Your first full tank is the starting point.',
    'm2.t': 'Ride.',
    'm2.d': 'Only topped up a bit? Switch off “Full tank” and those liters still count.',
    'm3.t': 'Fill up again.',
    'm3.d': 'Distance ÷ liters over the stretch. Done: your real average.',
    'm.note': 'Doing the math at every fill-up is easier. It’s also wrong whenever the tank isn’t full.',
    'f.kicker': 'Features',
    'f.title': 'Built for riding, not for typing.',
    'f1.k': 'Logging',
    'f1.t': 'Snap it. Logged.',
    'f1.d': 'Your iPhone reads the odometer and the receipt. You just check.',
    'f2.k': 'Consumption',
    'f2.t': 'Twisties or traffic? The chart tells.',
    'f2.d': 'Tank by tank, with the period average and an estimated benchmark for bikes like yours.',
    'f3.k': 'Maintenance',
    'f3.t': 'It remembers. You ride.',
    'f3.d': 'Oil, tires, chain and brakes, by distance or by date. The reminder arrives before it’s due.',
    'f4.k': 'Garage',
    'f4.t': 'One garage. Zero mix-ups.',
    'f4.d': 'Each bike keeps its own consumption and maintenance. Records add them all up.',
    'x1': '<span class="dim">No</span> sign-up.',
    'x2': '<span class="dim">No</span> password.',
    'x3': '<span class="dim">No</span> ads.',
    'x4': '<span class="dim">No</span> signal? <em class="accent flame-text">No problem.</em>',
    'bt.title': 'Use it at your next fuel-up.',
    'bt.d': 'Free on the Brazilian App Store. Requires an iPhone with iOS 18 or later; the app is in Portuguese for now.',
    'bt.mail': 'Questions or ideas? <a href="mailto:beta@carburante.motorcycles?subject=Carburante">beta@carburante.motorcycles</a>',
    'q.kicker': 'Questions',
    'q.title': 'Before you ask.',
    'q1.q': 'Is it free?',
    'q1.a': 'Yes. The app is free on the App Store and has no ads, subscribed or not. If you want more, there’s the optional Carburante Premium subscription: several bikes in the garage, full costs and achievement app icons.',
    'q2.q': 'Is there an Android version?',
    'q2.a': 'Not for now. Carburante is native to iPhone on purpose: fast, light and at home in the system.',
    'q9.q': 'Is it available outside Brazil?',
    'q9.a': 'For now it’s only on the Brazilian App Store, and the app is in Portuguese. Other countries and languages are in the plans.',
    'q3.q': 'Do I need an account?',
    'q3.a': 'No. Open it and go: the app works with no account to create and no password.',
    'q4.q': 'Where does my data live?',
    'q4.a': 'On your iPhone first, with a cloud copy isolated to your account. Usage stats are anonymous and can be turned off in Settings. Details in the <a href="privacidade/">privacy policy</a>.',
    'q7.q': 'What happens to my photos?',
    'q7.a': 'They’re read right on your iPhone. Receipt photos aren’t kept. The odometer photo stays as proof of the record: on your iPhone and in a private folder for your account in the cloud.',
    'q8.q': 'Can it read the pump display?',
    'q8.a': 'It does, but it isn’t 100% accurate yet. Glare, angle and segmented displays get in the way. That’s why the app always shows what it read before you save: you check it and fix anything that’s off. Printed receipts tend to come out more accurate.',
    'b.kicker': 'Achievements',
    'b.title': 'Riding is collecting, too.',
    'b.lede': '25 badges. No feature locked behind any of them.',
    'bd.fuel': 'First fuel-up',
    'bd.maint': 'First service',
    'bd.best': 'Above average',
    'bd.cc': '500cc Club',
    'bd.iron': 'Iron Butt · later',
    'r.kicker': 'On the horizon',
    'r.quote': 'The bike carries its events. <em class="accent">You keep your story.</em>',
    'r.lede': 'Today, a logbook. Next, the bike’s passport. None of it has a date.',
    'st.done': 'Shipped',
    'st.now': 'Now',
    'st.planned': 'Planned',
    'st.ideas': 'Ideas',
    'r1.t': 'Logbook',
    'r1.d': 'Consumption, maintenance, garage and badges.',
    'r2.t': 'On the App Store',
    'r2.d': 'This is where you come in.',
    'r3.t': 'Digital passport',
    'r3.d': 'The history becomes the bike’s.',
    'r6.t': 'Beyond the pump',
    'r6.d': 'Trips, weather and Iron Butt.',
    's.kicker': 'Behind the scenes',
    's.title': 'Made by someone who rides, too.',
    's.lede': 'I’m <a href="https://wagnerrosa.com" target="_blank" rel="noopener">Wagner Rosa</a>, product designer and rider for over two decades. I built Carburante for a simple reason: logging a fuel-up has to fit in a gas-station stop.',
    'alt.wagner': 'Wagner Rosa riding on a mountain road',
    's.code': 'Read the code',
    'ft.by': 'Built with <span class="footer__moto" role="img" aria-label="scooter">🛵</span> by <a href="https://wagnerrosa.com" target="_blank" rel="noopener">Wagner Rosa</a>',
    'ft.copy': '© 2026 Carburante. All rights reserved.',
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
  altNodes.forEach(function (el) { el.dataset.ptAlt = el.getAttribute('alt') || el.getAttribute('aria-label'); });

  var toggle = document.getElementById('lang-toggle');
  var current = 'pt';
  var onLang = []; // quem precisa refazer algo depois que o texto troca (ex.: palavras da ponte)

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
      el.setAttribute(el.tagName === 'IMG' ? 'alt' : 'aria-label', en && EN[key] ? EN[key] : el.dataset.ptAlt);
    });
    var m = META[lang];
    document.documentElement.lang = m.html;
    document.title = m.title;
    toggle.textContent = m.toggle;
    toggle.setAttribute('aria-label', m.toggleLabel);
    onLang.forEach(function (fn) { fn(); });
  }

  toggle.addEventListener('click', function () {
    var next = current === 'pt' ? 'en' : 'pt';
    apply(next);
    store(next);
    track('site_interaction', { event_category: 'ui', event_label: 'lang_' + next, event_location: 'nav' });
  });

  // Analytics — cliques classificados pelo href, sem data-track no HTML: o i18n troca o
  // innerHTML dos parágrafos, e links internos a eles perderiam atributos. Parâmetros
  // espelham o site_interaction do portfólio (mesmo formato, propriedade GA4 própria); o clique para a
  // App Store vai como generate_lead para ser marcado como key event.
  document.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    var box = a.closest('footer') ? { id: 'footer' } : a.closest('section[id], header[id]');
    var where = !box ? 'hero' : box.id === 'top' ? 'nav' : box.id;
    var href = a.getAttribute('href');
    if (a.classList.contains('js-store')) {
      track('generate_lead', { method: 'app_store', event_location: where });
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
  var fine = window.matchMedia && window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  var rider = document.querySelector('[data-rider]');
  if (rider) {
    var stage = rider.querySelector('.story__stage');
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

  // Beta: a roda do ícone acende quando aparece inteira na tela (ignição uma vez, depois o
  // loop) e o botão "acelera" (playbackRate + brilho). HEVC com alpha só no WebKit: o
  // Chrome toca HEVC mas ignora o alpha (fundo preto), por isso a escolha é por motor e
  // não pela ordem de <source>. Sem vídeo (Modo Pouca Energia, codec, "reduzir
  // movimento"), a imagem acesa fica no lugar.
  var beta = document.querySelector('[data-ignite]');
  if (beta) {
    var intro = beta.querySelectorAll('.beta__vid')[0];
    var loop = beta.querySelectorAll('.beta__vid')[1];
    var ext = null;
    if (!reduceMotion && 'IntersectionObserver' in window && intro.canPlayType) {
      if (navigator.vendor === 'Apple Computer, Inc.') ext = intro.canPlayType('video/mp4; codecs="hvc1"') ? 'mov' : null;
      else ext = intro.canPlayType('video/webm; codecs="vp9"') ? 'webm' : null;
    }
    if (!ext) {
      beta.classList.add('is-lit');
    } else {
      var lit = false, vidNow = intro, rate = 1, target = 1, rateFrame = 0, revved = false;
      intro.muted = loop.muted = true;
      var play = function (v) { var p = v.play(); if (p && p.catch) p.catch(function () {}); };
      var shown = function (v) {
        v.classList.add('is-shown');
        beta.classList.add('is-playing');
        if (v === loop) intro.classList.remove('is-shown'); // os dois têm alpha: o de baixo apareceria
      };
      intro.addEventListener('playing', function () { shown(intro); });
      loop.addEventListener('playing', function () { shown(loop); });
      intro.addEventListener('ended', function () { vidNow = loop; play(loop); });

      var load = function () {
        if (intro.getAttribute('src')) return;
        intro.preload = loop.preload = 'auto';
        intro.src = 'assets/art/roda-intro.' + ext;
        loop.src = 'assets/art/roda-loop.' + ext;
      };
      new IntersectionObserver(function (entries, obs) {
        if (entries[0].isIntersecting) { obs.disconnect(); load(); }
      }, { rootMargin: '800px 0px' }).observe(beta);

      // Acende com a roda inteira nos 80% de cima da tela; fora dessa faixa, pausa.
      var wheel = beta.querySelector('.beta__wheel');
      new IntersectionObserver(function (entries) {
        var e = entries[0];
        if (!e.isIntersecting) { vidNow.pause(); return; }
        if (lit) play(vidNow);
        else if (e.intersectionRatio >= 0.99) {
          lit = true;
          load();
          setTimeout(function () { beta.classList.add('is-lit'); play(intro); }, 250);
        }
      }, { rootMargin: '0px 0px -20% 0px', threshold: [0, 1] }).observe(wheel);

      // Acelerar: playbackRate sobe/desce suave (rAF); só depois de acesa. Teto 1,9×: acima
      // de 2× o Safari (AVFoundation) entra em avanço rápido e mostra ~4 quadros/s (medido:
      // 2,0× = 45 q/s, 2,1× = 3,5 q/s). Degraus de 0,05 para não trocar a taxa a cada quadro.
      var applied = 1;
      var setRate = function () {
        rate += (target - rate) * 0.14;
        if (Math.abs(target - rate) < 0.03) rate = target;
        var step = Math.round(rate * 20) / 20;
        if (step !== applied) { applied = step; intro.playbackRate = loop.playbackRate = step; }
        if (rate !== target) rateFrame = requestAnimationFrame(setRate);
      };
      var rev = function (on) {
        on = on && lit;
        beta.classList.toggle('is-rev', on);
        target = on ? 1.9 : 1;
        cancelAnimationFrame(rateFrame);
        rateFrame = requestAnimationFrame(setRate);
        if (on && !revved) {
          revved = true;
          track('site_interaction', { event_category: 'ui', event_label: 'beta_rev', event_location: 'beta' });
        }
      };
      var cta = beta.querySelector('.btn--flame');
      [cta, wheel].forEach(function (el) {
        el.addEventListener('pointerenter', function () { rev(true); });
        el.addEventListener('pointerleave', function () { rev(false); });
      });
      cta.addEventListener('focus', function () { rev(true); });
      cta.addEventListener('blur', function () { rev(false); });
    }
  }

  // Clipes do app (vídeos gravados no simulador no lugar dos prints). Só baixam e tocam na
  // tela (preload="none"); até o 1º quadro chegar, o poster já mostra a tela. Com "reduzir
  // movimento", economia de dados ou rede 2G (navigator.connection, onde existir), nenhum
  // vídeo é baixado e fica a imagem parada de data-still. Vídeo que falha também volta a ela.
  var net = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
  var slowNet = !!(net && (net.saveData || /2g$/.test(net.effectiveType || '')));
  var clipsOk = !reduceMotion && !slowNet && 'IntersectionObserver' in window;
  var toStill = function (v) {
    v.dataset.failed = '1';
    v.pause();
    if (v.dataset.still) v.poster = v.dataset.still;
  };
  var playClip = function (v) {
    if (!v || v.dataset.failed) return;
    if (v.preload !== 'auto') v.preload = 'auto';
    var p = v.play();
    if (p && p.catch) p.catch(function () {});
  };
  Array.prototype.forEach.call(document.querySelectorAll('video.clip'), function (v) {
    if (!clipsOk) { toStill(v); return; }
    // Erro de rede/decodificação chega no último <source>, não no <video>.
    var last = v.querySelector('source:last-of-type');
    if (last) last.addEventListener('error', function () { toStill(v); });
  });
  if (clipsOk) {
    var heroClip = document.querySelector('.hero video.clip');
    if (heroClip) {
      new IntersectionObserver(function (entries) {
        entries.forEach(function (e) { if (e.isIntersecting) playClip(heroClip); else heroClip.pause(); });
      }, { threshold: 0.25 }).observe(heroClip);
    }
  }

  // ---------- Seções presas à rolagem ----------
  // Um só ouvinte de scroll (rAF) avança tudo pela posição: nav, celular do hero, palavras da
  // ponte, painel do "Como medimos" e o carretel dos recursos. Sem .motion (sem JS ou com
  // "reduzir movimento"), cada seção é desenhada uma vez no estado final e fica estática.
  var motion = document.documentElement.classList.contains('motion');
  var clamp = function (v, a, b) { return v < a ? a : v > b ? b : v; };
  var ease = function (t) { return t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; };
  // Quadros-chave [[p, valor], ...] → valor em p, suavizado entre cada par
  var key = function (frames, p) {
    for (var i = 1; i < frames.length; i++) {
      if (p <= frames[i][0]) {
        var a = frames[i - 1], b = frames[i];
        return a[1] + (b[1] - a[1]) * ease(clamp((p - a[0]) / (b[0] - a[0] || 1), 0, 1));
      }
    }
    return frames[frames.length - 1][1];
  };
  // 0 → 1 enquanto o palco (sticky) está preso
  var pinProgress = function (el) {
    var r = el.getBoundingClientRect();
    var total = el.offsetHeight - window.innerHeight;
    return total > 0 ? clamp(-r.top / total, 0, 1) : 1;
  };
  var inView = function (el) {
    var r = el.getBoundingClientRect();
    return r.bottom > 0 && r.top < window.innerHeight;
  };

  // Nav: vidro depois da primeira rolagem
  var navEl = document.querySelector('.nav--overlay');

  // Hero: o celular endireita conforme o hero sai (--tilt 1 → 0) e segue o cursor (--px/--py)
  var hero = document.querySelector('[data-hero]');
  var heroPhone = hero && hero.querySelector('.phone--hero');
  if (heroPhone && motion && fine) {
    window.addEventListener('pointermove', function (e) {
      if (window.scrollY > window.innerHeight) return;
      heroPhone.style.setProperty('--px', (e.clientX / window.innerWidth * 2 - 1).toFixed(3));
      heroPhone.style.setProperty('--py', (e.clientY / window.innerHeight * 2 - 1).toFixed(3));
    }, { passive: true });
  }

  // Ponte: cada palavra vira <span class="w"> e acende conforme a frase sobe na tela
  var words = document.querySelector('[data-words]');
  var wordEls = [];
  // Percorre os nós e embrulha só o texto: o <em class="accent"> continua em volta das palavras dele.
  var wrapWords = function (node) {
    Array.prototype.slice.call(node.childNodes).forEach(function (n) {
      if (n.nodeType === 1) { wrapWords(n); return; }
      if (n.nodeType !== 3) return;
      var frag = document.createDocumentFragment();
      n.textContent.split(/(\s+)/).forEach(function (t) {
        if (!t) return;
        if (/^\s+$/.test(t)) { frag.appendChild(document.createTextNode(t)); return; }
        var w = document.createElement('span');
        w.className = 'w';
        w.textContent = t;
        frag.appendChild(w);
      });
      node.replaceChild(frag, n);
    });
  };
  var splitWords = function () {
    if (!words || !motion) return;
    wrapWords(words);
    wordEls = Array.prototype.slice.call(words.querySelectorAll('.w'));
  };
  splitWords();
  onLang.push(function () { splitWords(); frame(); });

  // Títulos linha a linha: mede onde o navegador quebrou cada linha (com a fonte já carregada)
  // e remonta como .ln > .li; o <em>/<span> de cada palavra volta em volta dela. O &nbsp; não
  // quebra (o split é só em espaço comum). Refaz ao trocar idioma e ao redimensionar.
  var riseEls = motion ? Array.prototype.slice.call(document.querySelectorAll('[data-rise]')) : [];
  var splitLines = function (el) {
    if (el._src == null) el._src = el.innerHTML;
    el.innerHTML = el._src;
    var tw = [];
    (function walk(node) {
      Array.prototype.slice.call(node.childNodes).forEach(function (n) {
        if (n.nodeType === 1) { walk(n); return; }
        if (n.nodeType !== 3) return;
        var frag = document.createDocumentFragment();
        n.textContent.split(/([ \t\n\r]+)/).forEach(function (t) {
          if (!t) return;
          if (/^[ \t\n\r]+$/.test(t)) { frag.appendChild(document.createTextNode(' ')); return; }
          var w = document.createElement('span');
          w.className = 'tw';
          w.textContent = t;
          frag.appendChild(w);
          tw.push(w);
        });
        n.parentNode.replaceChild(frag, n);
      });
    })(el);
    var lines = [], top = null;
    tw.forEach(function (w) {
      var t = w.getBoundingClientRect().top;
      if (top === null || t - top > w.offsetHeight * .5) { lines.push([]); top = t; }
      lines[lines.length - 1].push(w);
    });
    var out = document.createDocumentFragment();
    lines.forEach(function (words, i) {
      var ln = document.createElement('span');
      var li = document.createElement('span');
      ln.className = 'ln';
      li.className = 'li';
      li.style.setProperty('--i', i);
      var holder = null, src = null;
      words.forEach(function (w, k) {
        var parent = w.parentNode === el ? null : w.parentNode;
        if (parent && parent === src) { holder.appendChild(document.createTextNode(' ' + w.textContent)); return; }
        if (k) li.appendChild(document.createTextNode(' '));
        if (parent) {
          holder = parent.cloneNode(false);
          holder.textContent = w.textContent;
          li.appendChild(holder);
        } else {
          holder = null;
          li.appendChild(document.createTextNode(w.textContent));
        }
        src = parent;
      });
      ln.appendChild(li);
      out.appendChild(ln);
    });
    el.innerHTML = '';
    el.appendChild(out);
    el.classList.add('is-split');
  };
  var splitAll = function () { riseEls.forEach(splitLines); };
  onLang.push(function () { riseEls.forEach(function (el) { el._src = null; }); splitAll(); });
  var resizeTimer = 0, lastW = window.innerWidth;
  window.addEventListener('resize', function () {
    if (window.innerWidth === lastW) return; // barra do Safari subindo/descendo muda só a altura
    lastW = window.innerWidth;
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(splitAll, 180);
  }, { passive: true });
  if (riseEls.length) {
    var riseIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('is-in'); riseIO.unobserve(e.target); } });
    }, { threshold: .2, rootMargin: '0px 0px -8% 0px' });
  }

  // Ignição: com a fonte pronta (no máximo 700 ms de espera), mede as linhas e acende o hero.
  var ignited = false;
  var ignite = function () {
    if (ignited) return;
    ignited = true;
    splitAll();
    riseEls.forEach(function (el) { if (!el.closest('.hero')) riseIO.observe(el); });
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { if (document.fonts.status === 'loaded') splitAll(); });
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        if (hero) hero.classList.add('is-lit');
        var h1 = hero && hero.querySelector('h1');
        if (h1) h1.classList.add('is-in');
      });
    });
  };

  // Como medimos: o painel conta a história.
  var measure = document.querySelector('[data-measure]');
  var cluster, drums = [], fuelSegs = [], events = [], steps = [], measureDone = false;
  if (measure) {
    cluster = measure.querySelector('.cluster');
    drums = Array.prototype.map.call(measure.querySelectorAll('.odo__d'), function (d) {
      var strip = d.firstElementChild;
      strip.innerHTML = '<i>0</i><i>1</i><i>2</i><i>3</i><i>4</i><i>5</i><i>6</i><i>7</i><i>8</i><i>9</i><i>0</i>';
      return strip;
    });
    fuelSegs = Array.prototype.slice.call(measure.querySelectorAll('.fuel i'));
    events = Array.prototype.slice.call(measure.querySelectorAll('.events li'));
    steps = Array.prototype.slice.call(measure.querySelectorAll('.steps li'));
    if (motion) {
      new IntersectionObserver(function (entries, obs) {
        if (entries[0].isIntersecting) { cluster.classList.add('is-on'); obs.disconnect(); }
      }, { threshold: .6 }).observe(cluster);
    }
  }
  // Hodômetro de tambor: o último dígito gira sem parar; os de cima só viram quando todos
  // os de baixo passam pelo 9 (o "vai um" mecânico).
  var setOdo = function (v) {
    for (var i = 0; i < drums.length; i++) {
      var p10 = Math.pow(10, i);
      var pos = Math.floor(v / p10) % 10 + Math.max(0, (v % p10) - (p10 - 1));
      drums[drums.length - 1 - i].style.transform = 'translateY(' + (-pos).toFixed(4) + 'em)';
    }
  };
  // Roteiro (p = 0 → 1): enche na reserva → roda 176 km → parcial de 6,0 L → roda mais
  // 176 km → enche de novo (11,3 L) → 352 km ÷ 17,3 L = 20,3 km/l.
  var ODO = [[0, 22039], [.14, 22039], [.40, 22215], [.50, 22215], [.74, 22391], [1, 22391]];
  var FUEL = [[0, .22], [.12, 1], [.14, 1], [.40, .4], [.43, .4], [.48, .72], [.50, .72], [.74, .12], [.76, .12], [.86, 1], [1, 1]];
  var renderMeasure = function (p) {
    setOdo(key(ODO, p));
    var level = key(FUEL, p);
    fuelSegs.forEach(function (s, i) { s.style.setProperty('--on', clamp(level * fuelSegs.length - i, 0, 1).toFixed(3)); });
    cluster.classList.toggle('is-low', level < .2);
    [.11, .47, .85].forEach(function (at, i) { if (events[i]) events[i].classList.toggle('is-on', p >= at); });
    var step = p < .13 ? 0 : p < .75 ? 1 : 2;
    steps.forEach(function (s, i) { s.classList.toggle('is-on', i === step); });
    var done = p >= .88;
    cluster.classList.toggle('is-done', done);
    if (done && !measureDone) {
      measureDone = true;
      track('site_interaction', { event_category: 'ui', event_label: 'measure_done', event_location: 'consumo' });
    }
  };

  // Recursos: um quarto da rolagem presa para cada recurso; o clipe do ativo toca em loop.
  var reel = document.querySelector('[data-reel]');
  var feats = reel ? Array.prototype.slice.call(reel.querySelectorAll('.feature')) : [];
  var fclips = feats.map(function (f) { return f.querySelector('video.clip'); });
  var ticks = reel ? Array.prototype.slice.call(reel.querySelectorAll('.reel__ticks li')) : [];
  var reelActive = -1, reelVisible = false;
  var setReel = function (i, visible) {
    if (i !== reelActive) {
      feats.forEach(function (f, k) {
        f.classList.toggle('is-active', k === i);
        f.classList.toggle('is-past', k < i);
      });
      fclips.forEach(function (v, k) {
        if (!v || k === i) return;
        v.pause();
      });
      if (fclips[i] && clipsOk) { try { fclips[i].currentTime = 0; } catch (e) { /* sem metadados */ } }
      reelActive = i;
    }
    if (!clipsOk) return;
    if (visible) playClip(fclips[i]); else if (fclips[i]) fclips[i].pause();
  };

  var manifesto = document.querySelector('.manifesto');
  var rail = document.querySelector('[data-rail]');
  var railTrack = rail && rail.querySelector('.badge-grid');

  var frame = function () {
    var y = window.scrollY, vh = window.innerHeight;
    if (navEl) navEl.classList.toggle('is-stuck', y > 8);
    if (!motion) return;

    if (heroPhone && y < vh * 1.5) {
      heroPhone.style.setProperty('--tilt', (1 - ease(clamp(y / (hero.offsetHeight * .75), 0, 1))).toFixed(3));
    }
    if (wordEls.length && inView(words)) {
      var r = words.getBoundingClientRect();
      var lit = Math.round(clamp((vh * .88 - r.top) / (vh * .5), 0, 1) * wordEls.length);
      wordEls.forEach(function (w, i) { w.classList.toggle('on', i < lit); });
    }
    if (measure && inView(measure)) renderMeasure(pinProgress(measure));
    if (manifesto && inView(manifesto)) {
      var mr = manifesto.getBoundingClientRect();
      var heat = clamp((vh * .75 - mr.top) / (mr.height * .7), 0, 1);
      manifesto.style.setProperty('--heat', heat.toFixed(3));
      manifesto.classList.toggle('is-hot', heat > .8);
    }
    if (railTrack && inView(rail)) {
      var rr = rail.getBoundingClientRect();
      var over = Math.max(0, railTrack.scrollWidth - rail.clientWidth);
      railTrack.style.setProperty('--bx', (-over * clamp((vh - rr.top) / (vh + rr.height), 0, 1)).toFixed(1) + 'px');
    }
    if (reel) {
      var visible = inView(reel);
      if (visible || reelVisible) {
        var p = pinProgress(reel);
        var n = feats.length;
        setReel(Math.min(n - 1, Math.floor(p * n)), visible);
        ticks.forEach(function (t, k) { t.firstElementChild.style.setProperty('--p', clamp(p * n - k, 0, 1).toFixed(3)); });
      }
      reelVisible = visible;
    }
  };

  // Estático: painel no fim da história. Os clipes ficam na imagem parada (clipsOk também
  // depende de "reduzir movimento").
  if (measure && !motion) renderMeasure(1);

  var ticking = false;
  var onScroll = function () {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () { ticking = false; frame(); });
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll, { passive: true });

  // Prioridade: ?lang=en|pt (link compartilhável) > escolha salva > idioma do navegador.
  // Depois de montar painel e palavras: apply() chama os ganchos de onLang.
  var param = (location.search.match(/[?&]lang=(pt|en)\b/) || [])[1];
  var saved = stored();
  var navLang = (navigator.language || 'pt').toLowerCase();
  apply(param || (saved === 'en' || saved === 'pt' ? saved : (navLang.indexOf('pt') === 0 ? 'pt' : 'en')));
  frame();
  if (motion) {
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(ignite);
      setTimeout(ignite, 700);
    } else ignite();
  }


  // Nome do rodapé do tamanho da largura, qualquer que seja a fonte: mede em 100px e escala.
  var mark = document.querySelector('.footer__mark');
  var fitMark = function () {
    if (!mark) return;
    var span = mark.firstElementChild;
    mark.style.fontSize = '100px';
    var w = span.getBoundingClientRect().width;
    if (w) mark.style.fontSize = (100 * mark.clientWidth * .96 / w).toFixed(1) + 'px';
  };
  fitMark();
  window.addEventListener('resize', fitMark, { passive: true });
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(fitMark);

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
  }, { threshold: 0 });
  items.forEach(function (el) { io.observe(el); });
})();
