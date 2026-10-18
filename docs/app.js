// Carburante — landing page. i18n PT/EN, seções presas à rolagem, reveal on scroll.
(function () {
  'use strict';

  // O HTML já vem em pt-BR (SEO / sem JS). Só o inglês mora aqui; o português é
  // lido do próprio DOM na carga e restaurado ao voltar.
  var EN = {
    'skip': 'Skip to content',
    'hero.title': 'How much does your bike <em class="accent flame-text">really&nbsp;burn?</em>',
    'hero.lede': 'Snap the odometer at the pump. Carburante works out your real average and warns you before the next oil change. Even with no signal.',
    'cta.store': 'Download on the App Store',
    'cta.badge': '<img src="assets/store/app-store-en-us.svg" alt="Download on the App Store" width="144" height="48">',
    'cta.nav': 'Get it free',
    'hero.meta': 'Free · No sign-up · No ads · iOS 18+ · Brazil only, in Portuguese for now',
    'alt.hero': 'Carburante Summary screen with a Harley-Davidson: 20.3 km/l average, cost per km and monthly spend. The app switches bikes and changes color.',
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
    'm.note': 'Dividing km by liters at every stop is wrong whenever the tank isn’t full. That’s why Carburante only closes the math on a full tank.',
    'f.kicker': 'Features',
    'f.title': 'Built for <em class="accent">riding,</em><br> <span class="ride__dim">not for</span> <span class="ride__x">typing.</span>',
    'f1.k': 'Logging',
    'f1.t': 'Snap it. Logged.',
    'f1.d': 'Your iPhone reads the odometer, then the pump or the receipt. You just check.',
    'sim.s1': 'Odometer',
    'sim.s2': 'Pump or receipt',
    'sim.s3': 'Check and save',
    'sim.v1': '22,039 km',
    'sim.v2': 'R$ 28.49 · 4.135 L',
    'sim.v3': '20.1 km/l',
    'sim.c.odo': 'Odometer',
    'sim.c.pump': 'Pump',
    'sim.c.receipt': 'Receipt',
    'sim.or': 'or',
    'sim.a.scan': 'Scan',
    'sim.a.next': 'Next',
    'sim.a.review': 'Review',
    'sim.a.save': 'Save fuel-up',
    'sim.cta': 'Get it free',
    'sim.again': 'Try again',
    'f2.k': 'Consumption',
    'f2.t': 'Twisties or traffic? The chart tells.',
    'f2.d': 'One bar per tank. Next to it, an estimated benchmark for bikes like yours.',
    'f3.k': 'Maintenance',
    'f3.t': 'It remembers. You ride.',
    'f3.d': 'Oil, tires, chain and brakes, by distance or by date. The reminder arrives before it’s due.',
    'f4.k': 'Garage',
    'f4.t': 'Two bikes, two averages. Nothing mixes.',
    'f4.d': 'Each bike keeps its own consumption and maintenance. Part of Carburante Premium.',
    'x1': '<span class="dim">No</span> sign-up.',
    'x2': '<span class="dim">No</span> password.',
    'x3': '<span class="dim">No</span> ads.',
    'x4': '<span class="dim">No</span> signal? <em class="accent flame-text">No problem.</em>',
    'bt.title': 'Use it at your next fuel-up.',
    'bt.d': 'Free, no sign-up. It fits in a gas-station stop. iPhone with iOS 18 or later; the app is in Portuguese for now.',
    'bt.mail': 'Questions or ideas? <a href="mailto:beta@carburante.motorcycles?subject=Carburante">beta@carburante.motorcycles</a>',
    'q.kicker': 'Questions',
    'q.title': 'Before you ask.',
    'q1.q': 'Is it free?',
    'q1.a': 'Yes. The app is free on the App Store and has no ads, subscribed or not. If you want more, there’s the optional Carburante Premium subscription: several bikes in the garage, full costs and achievement app icons.',
    'q11.q': 'Will it work with my bike?',
    'q11.a': 'Any make and model. If yours isn’t on the list, just type it in.',
    'q2.q': 'Is there an Android version?',
    'q2.a': 'Not for now. Carburante is native to iPhone on purpose: fast, light and at home in the system.',
    'q9.q': 'Is it available outside Brazil?',
    'q9.a': 'For now it’s only on the Brazilian App Store, and the app is in Portuguese. Other countries and languages are in the plans.',
    'q3.q': 'Do I need an account?',
    'q3.a': 'No. Open it and go: the app works with no account to create and no password.',
    'q10.q': 'I forgot to log a fuel-up. Now what?',
    'q10.a': 'No problem. When the odometer jumps too far, the app asks. Tap “Abasteci sem registrar” (“I filled up without logging”): the average restarts from there and the distance keeps counting.',
    'q4.q': 'Where does my data live?',
    'q4.a': 'On your iPhone first, with a cloud copy isolated to your account. Usage stats are anonymous and can be turned off in Settings. Details in the <a href="privacidade/">privacy policy</a>.',
    'q7.q': 'What happens to my photos?',
    'q7.a': 'They’re read right on your iPhone. Pump and receipt photos aren’t kept. The odometer photo stays as proof of the record: on your iPhone and in a private folder for your account in the cloud.',
    'q8.q': 'Can it read the pump display?',
    'q8.a': 'It does, but it isn’t 100% accurate yet. Glare, angle and segmented displays get in the way. That’s why the app always shows what it read before you save: you check it and fix anything that’s off. Printed receipts tend to come out more accurate.',
    'b.kicker': 'Achievements',
    'b.title': 'Riding is collecting, too.',
    'b.lede': '25 badges. Every one earned riding.',
    'bd.fuel': 'First fuel-up',
    'bd.maint': 'First service',
    'bd.best': 'Above average',
    'bd.cc': '500cc Club',
    'bd.iron': 'Iron Butt · later',
    'r.kicker': 'Roadmap',
    'r.quote': 'Today, the bike’s logbook. <em class="accent">Tomorrow, its passport.</em>',
    'r.lede': 'When the bike changes hands, its history goes with it. No date yet.',
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
    'ft.by': 'Built with <span class="footer__moto" role="img" aria-label="motorcycle">🏍️</span> by <a href="https://wagnerrosa.com" target="_blank" rel="noopener">Wagner Rosa</a>',
    'ft.copy': '© 2026 Carburante. All rights reserved.',
    'ft.privacy': 'Privacy',
    'ft.legal': 'Motorcycle manufacturer names and logos shown in the screens are trademarks or registered trademarks of their respective owners, used only to identify the registered bike. Carburante is independent and is not affiliated with, sponsored or endorsed by any manufacturer.'
  };

  var META = {
    pt: {
      title: document.title,
      toggle: 'EN', toggleLabel: 'EN, switch to English', html: 'pt-BR'
    },
    en: {
      title: 'Carburante · How much does your bike really burn?',
      toggle: 'PT', toggleLabel: 'PT, mudar para português', html: 'en'
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
      var html = en && EN[key] ? EN[key] : el.dataset.pt;
      if (el.innerHTML !== html) el.innerHTML = html; // na carga em PT não repinta nada (LCP)
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
  // O Safari do iPhone só aplica :active (botão afundando no toque) se houver um ouvinte de toque
  document.addEventListener('touchstart', function () {}, { passive: true });
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
      // No toque, pointerleave chega junto com o dedo saindo: a roda segue acelerando um instante
      var revOff = 0;
      [cta, wheel].forEach(function (el) {
        el.addEventListener('pointerenter', function () { clearTimeout(revOff); rev(true); });
        el.addEventListener('pointerleave', function (e) {
          clearTimeout(revOff);
          if (e.pointerType === 'touch') revOff = setTimeout(function () { rev(false); }, 1100);
          else rev(false);
        });
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
  // Capas dos clipes abaixo da dobra só baixam perto da tela: não disputam a carga com o hero.
  var lazyPosters = Array.prototype.slice.call(document.querySelectorAll('video[data-poster]'));
  var showPoster = function (v) { if (!v.dataset.failed && !v.poster) v.poster = v.dataset.poster; };
  if ('IntersectionObserver' in window) {
    var posterIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { showPoster(e.target); posterIO.unobserve(e.target); } });
    }, { rootMargin: '1200px 0px' });
    lazyPosters.forEach(function (v) { posterIO.observe(v); });
  } else lazyPosters.forEach(showPoster);
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

  // Cápsula: o tanque (linha da base) enche com a leitura; o meio mostra o capítulo atual, lido
  // dos títulos [data-chapter] (segue o idioma). No carretel dos recursos: "Recursos · Registro".
  var capsule = document.querySelector('.capsule');
  var chapterEl = capsule && capsule.querySelector('.capsule__chapter');
  var chapterSpan = chapterEl && chapterEl.firstElementChild;
  var chapters = Array.prototype.slice.call(document.querySelectorAll('[data-chapter]'));
  var chapterNow = null, chapterTimer = 0;
  var chapterText = function (el) {
    var v = el.getAttribute('data-chapter');
    return v === '-' ? '' : v || el.textContent.trim();
  };
  var setChapter = function (t) {
    if (!chapterEl || t === chapterNow) return;
    chapterNow = t;
    chapterEl.classList.add('is-swap');
    clearTimeout(chapterTimer);
    chapterTimer = setTimeout(function () { chapterSpan.textContent = t; chapterEl.classList.remove('is-swap'); }, 200);
  };

  // Baixar (cápsula): uma chama corre a borda como um cometa, com rastro do vermelho ao branco.
  // Traços SVG empilhados (cada um mais curto e mais quente) num contorno arredondado: velocidade
  // e rastro constantes ao longo da borda (conic-gradient dispara nos cantos). É um motor: dá a
  // partida quando a página acende, acelera com a rolagem e no hover, e o rastro cresce com a
  // rotação. Uma segunda brasa, mais lenta, é ultrapassada de tempos em tempos.
  var cta = capsule && capsule.querySelector('.capsule__cta');
  if (cta && document.createElementNS) {
    var NS = 'http://www.w3.org/2000/svg';
    var fireSvg = function (cls) {
      var s = document.createElementNS(NS, 'svg');
      s.setAttribute('class', 'cta__fire ' + cls);
      s.setAttribute('aria-hidden', 'true');
      s.setAttribute('focusable', 'false');
      cta.insertBefore(s, cta.firstChild);
      return s;
    };
    var glowSvg = fireSvg('cta__fire--glow'), lineSvg = fireSvg('cta__fire--line');
    var mix = function (stops, t) { // stops: [[t, r, g, b]]
      for (var i = 1; i < stops.length; i++) if (t <= stops[i][0]) {
        var a = stops[i - 1], b = stops[i], k = (t - a[0]) / (b[0] - a[0]);
        return 'rgb(' + [1, 2, 3].map(function (c) { return Math.round(a[c] + (b[c] - a[c]) * k); }).join(',') + ')';
      }
    };
    var FLAME = [[0, 255, 45, 26], [.45, 255, 106, 0], [.75, 255, 176, 0], [.92, 255, 226, 122], [1, 255, 246, 224]];
    var EMBER = [[0, 255, 45, 26], [.6, 255, 106, 0], [1, 255, 176, 0]];
    var layers = [];
    // len = fração do contorno (na marcha lenta); c = cometa (0 chama, 1 brasa)
    var addLayer = function (svg, c, len, width, color, op, round) {
      var el = document.createElementNS(NS, 'path');
      el.setAttribute('stroke', color);
      el.setAttribute('stroke-width', width);
      el.setAttribute('stroke-opacity', op);
      if (round) el.setAttribute('stroke-linecap', 'round');
      svg.appendChild(el);
      layers.push({ el: el, c: c, len: len });
    };
    addLayer(glowSvg, 1, .12, 6, '#ff3b30', .6);
    addLayer(glowSvg, 0, .28, 7, '#ff5a00', .9);
    addLayer(glowSvg, 0, .06, 10, '#ffb347', 1, true);
    for (var e = 0; e < 3; e++) {
      var te = e / 2;
      addLayer(lineSvg, 1, .015 + .13 * Math.pow(1 - te, 1.5), 1 + .6 * te, mix(EMBER, te), .25 + .45 * te);
    }
    for (var f = 0; f < 7; f++) {
      var tf = f / 6;
      addLayer(lineSvg, 0, .012 + .3 * Math.pow(1 - tf, 1.5), 1.2 + 1.1 * tf, mix(FLAME, tf), .35 + .65 * tf, tf > .8);
    }

    var P = 0, pos = [.1, .6], rv = 0, rvSet = -1;
    var shape = function () {
      var w = cta.offsetWidth, h = cta.offsetHeight, r = Math.min(13, h / 2);
      if (!w) return;
      P = 2 * (w - 2 * r) + 2 * (h - 2 * r) + 2 * Math.PI * r;
      var arc = ' A' + r + ' ' + r + ' 0 0 1 ';
      var d = 'M' + r + ' 0H' + (w - r) + arc + w + ' ' + r + 'V' + (h - r) + arc + (w - r) + ' ' + h +
        'H' + r + arc + '0 ' + (h - r) + 'V' + r + arc + r + ' 0Z';
      layers.forEach(function (l) { l.el.setAttribute('d', d); });
    };
    var draw = function () {
      var grow = 1 + .9 * rv;
      layers.forEach(function (l) {
        var L = Math.min(l.len * grow, .9) * P, head = pos[l.c] * P;
        l.el.setAttribute('stroke-dasharray', L.toFixed(1) + ' ' + (P - L).toFixed(1));
        l.el.setAttribute('stroke-dashoffset', (L - head).toFixed(1));
      });
      if (Math.abs(rv - rvSet) > .004) { rvSet = rv; cta.style.setProperty('--rev', rv.toFixed(3)); }
    };
    shape();
    if ('ResizeObserver' in window) new ResizeObserver(function () { shape(); draw(); }).observe(cta);
    else window.addEventListener('resize', function () { shape(); draw(); });

    if (!motion) { cta.style.setProperty('--heat', '1'); draw(); }
    else {
      var IDLE = .2, MAX = 1.6; // voltas por segundo
      var v = 0, heat = 0, heatSet = -1, revving = false, started = 0, lastT = 0, lastY = window.scrollY, sv = 0, revTimer = 0;
      var revOn = function () { clearTimeout(revTimer); revving = true; };
      var revOff = function () { revving = false; };
      cta.addEventListener('pointerenter', function (ev) { if (ev.pointerType !== 'touch') revOn(); });
      cta.addEventListener('pointerleave', function (ev) { if (ev.pointerType !== 'touch') revOff(); });
      cta.addEventListener('pointerdown', function (ev) { if (ev.pointerType === 'touch') { revOn(); revTimer = setTimeout(revOff, 1200); } });
      cta.addEventListener('focus', revOn);
      cta.addEventListener('blur', revOff);
      var tick = function (t) {
        var dt = lastT ? Math.min((t - lastT) / 1000, .05) : 0;
        lastT = t;
        var y = window.scrollY;
        if (dt) sv += (Math.abs(y - lastY) / dt - sv) * (1 - Math.exp(-6 * dt));
        lastY = y;
        // partida: um tranco forte quando a cápsula desce, que assenta na marcha lenta
        if (!started && document.documentElement.classList.contains('is-lit')) started = t;
        var on = started && t - started > 450;
        if (on && !heat) v = 1.3;
        var target = !on ? 0 : revving ? MAX : IDLE + (MAX - IDLE) * .75 * Math.min(sv / 2400, 1);
        v += (target - v) * (1 - Math.exp(-(target > v ? 5 : 1.4) * dt));
        heat += ((on ? 1 : 0) - heat) * (1 - Math.exp(-2.6 * dt));
        if (on && heat < .001) heat = .001;
        pos[0] = (pos[0] + v * dt) % 1;
        pos[1] = (pos[1] + v * .62 * dt) % 1;
        rv = clamp((v - IDLE) / (MAX - IDLE), 0, 1);
        if (Math.abs(heat - heatSet) > .004 || (heat > .995 && heatSet < 1)) {
          heatSet = heat > .995 ? 1 : heat;
          cta.style.setProperty('--heat', heatSet.toFixed(3));
        }
        draw();
        requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    }
  }

  // Hero: o celular endireita conforme o hero sai (--tilt 1 → 0, até 16°) e segue o cursor (--px/--py)
  var hero = document.querySelector('[data-hero]');
  var heroPhone = hero && hero.querySelector('.phone--hero');
  var heroVisual = hero && hero.querySelector('.hero__visual');
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
  onLang.push(function () { splitWords(); chapterNow = null; frame(); });

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
        document.documentElement.classList.add('is-lit');
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

  // Registro: o simulador. Passos: odo → odo-read → fuel → fuel-read → review → saved.
  // Cada objeto é um botão: tocar (ou Enter) leva o objeto até o celular; arrastar e soltar em
  // cima do celular também. A "câmera" sobe, foca, a linha passa, os cantos travam no número e
  // a tela avança (quadros do app de verdade). Com "reduzir movimento": sem voo, sem foco.
  var sim = document.querySelector('[data-sim]');
  var SIM = {
    pt: {
      drop: { odo: 'Arraste o hodômetro até aqui', fuel: 'Agora a bomba ou o comprovante' },
      tap: { odo: 'Toque no hodômetro', fuel: 'Toque na bomba ou no comprovante' },
      arrow: ['arraste', 'toque'],
      hint: { odo: 'Experimente: leve o hodômetro até o celular.', fuel: 'Agora a bomba ou o comprovante.', review: 'Confira e toque em Salvar.', saved: 'Pronto: registrado em {n} s.' },
      read: { odo: ['Lendo o hodômetro…', 'Hodômetro lido'], pump: ['Lendo a bomba…', 'Bomba lida'], receipt: ['Lendo o comprovante…', 'Comprovante lido'] },
      val: { odo: '22.039 km', fuel: 'R$ 28,49 · 4,135 L' }
    },
    en: {
      drop: { odo: 'Drag the odometer here', fuel: 'Now the pump or the receipt' },
      tap: { odo: 'Tap the odometer', fuel: 'Tap the pump or the receipt' },
      arrow: ['drag', 'tap'],
      hint: { odo: 'Try it: bring the odometer to the phone.', fuel: 'Now the pump or the receipt.', review: 'Check it and tap “Salvar” (Save).', saved: 'Done: logged in {n} s.' },
      read: { odo: ['Reading the odometer…', 'Odometer read'], pump: ['Reading the pump…', 'Pump read'], receipt: ['Reading the receipt…', 'Receipt read'] },
      val: { odo: '22,039 km', fuel: 'R$ 28.49 · 4.135 L' }
    }
  };
  if (sim) (function () {
    var screen = sim.querySelector('.sim__screen');
    var shots = Array.prototype.slice.call(sim.querySelectorAll('.sim__shot'));
    var cam = sim.querySelector('.sim__cam');
    var view = cam.querySelector('.sim__view');
    var statusT = cam.querySelector('.sim__status span');
    var box = cam.querySelector('.sim__box');
    var pill = cam.querySelector('.sim__pill');
    var dropT = sim.querySelector('.sim__drop-t');
    var arrowTs = Array.prototype.slice.call(sim.querySelectorAll('.sim__arrow-t'));
    var hint = sim.querySelector('.sim__hint');
    var foot = sim.querySelector('.sim__foot');
    var stepEls = Array.prototype.slice.call(sim.querySelectorAll('.sim__steps li'));
    var props = {};
    Array.prototype.forEach.call(sim.querySelectorAll('[data-prop]'), function (b) { props[b.getAttribute('data-prop')] = b; });
    var pumpDigits = Array.prototype.slice.call(props.pump.querySelectorAll('[data-pump]'));
    var quick = !motion || !Element.prototype.animate;
    var OUT = 'cubic-bezier(.32, .72, 0, 1)';
    var step = '', shot = 4, busy = false, timers = [], t0 = 0, secs = 0, idleTimer = 0, pumpRun = 0;
    var T = function (k) { return SIM[current === 'en' ? 'en' : 'pt'][k]; };
    var later = function (fn, ms) { timers.push(setTimeout(fn, ms)); };

    var setShot = function (n, how) {
      var prev = shots[shot], next = shots[n];
      if (n === shot) return;
      shots.forEach(function (s, k) { s.classList.toggle('is-on', k === n); });
      shot = n;
      if (quick || !prev) return;
      if (how === 'push') {
        next.animate({ transform: ['translateX(30%)', 'none'], opacity: [0, 1] }, { duration: 460, easing: OUT });
        prev.animate({ transform: ['none', 'translateX(-14%)'], opacity: [1, 0] }, { duration: 460, easing: OUT });
      } else if (how === 'dismiss') {
        // a folha do registro desce e revela o Resumo
        prev.style.zIndex = 2;
        prev.animate({ transform: ['none', 'translateY(100%)'], opacity: [1, 1] }, { duration: 560, easing: OUT }).onfinish = function () { prev.style.zIndex = ''; };
        next.animate({ opacity: [1, 1], filter: ['brightness(.6)', 'none'] }, { duration: 560, easing: 'ease-out' });
      }
    };
    var countPump = function (to, now) {
      cancelAnimationFrame(pumpRun);
      var put = function (e) { pumpDigits.forEach(function (el) { el.textContent = (parseFloat(el.dataset.pump) * e).toFixed(+el.dataset.dec); }); };
      if (!to || quick || now) { put(to); return; }
      var s0 = performance.now();
      var tick = function (now) {
        var k = Math.min(1, (now - s0) / 1500);
        put(1 - Math.pow(1 - k, 3));
        if (k < 1) pumpRun = requestAnimationFrame(tick);
      };
      pumpRun = requestAnimationFrame(tick);
    };
    var renderText = function () {
      if (step === 'odo' || step === 'fuel') dropT.textContent = T(fine ? 'drop' : 'tap')[step];
      arrowTs.forEach(function (el) { el.textContent = T('arrow')[fine ? 0 : 1]; });
      var h = T('hint');
      if (step === 'saved') hint.textContent = h.saved.replace('{n}', secs);
      else if (h[step]) hint.textContent = h[step];
    };
    onLang.push(renderText);
    var setStep = function (s) {
      step = s;
      sim.setAttribute('data-step', s);
      var at = { odo: 0, 'odo-read': 0, fuel: 1, 'fuel-read': 1, review: 2, saved: 3 }[s];
      var read = /-read$/.test(s);
      stepEls.forEach(function (li, k) {
        li.classList.toggle('is-done', k < at || (k === at && read));
        li.classList.toggle('is-on', k === at);
      });
      var want = s === 'odo' ? ['odo'] : s === 'fuel' ? ['pump', 'receipt'] : [];
      Object.keys(props).forEach(function (k) {
        var on = want.indexOf(k) >= 0;
        props[k].setAttribute('aria-disabled', on ? 'false' : 'true');
        props[k].classList.toggle('is-next', on);
      });
      renderText();
    };
    var clearIdle = function () { clearTimeout(idleTimer); sim.classList.remove('is-idle'); };
    var armIdle = function () {
      clearIdle();
      idleTimer = setTimeout(function () { if (!busy && (step === 'odo' || step === 'fuel')) sim.classList.add('is-idle'); }, 2600);
    };
    var press = function (sel) {
      var h = sim.querySelector(sel);
      if (!h) return;
      h.classList.add('is-press');
      setTimeout(function () { h.classList.remove('is-press'); }, 220);
    };
    var union = function (els) {
      var r = null;
      Array.prototype.forEach.call(els, function (el) {
        var b = el.getBoundingClientRect();
        r = r ? { l: Math.min(r.l, b.left), t: Math.min(r.t, b.top), r: Math.max(r.r, b.right), b: Math.max(r.b, b.bottom) } : { l: b.left, t: b.top, r: b.right, b: b.bottom };
      });
      return r;
    };

    // A câmera lê o objeto e a tela avança para o campo preenchido
    var scan = function (kind) {
      var fuel = kind !== 'odo';
      busy = true;
      sim.classList.add('is-busy');
      clearIdle();
      if (!t0) {
        t0 = performance.now();
        track('site_interaction', { event_category: 'ui', event_label: 'sim_start', event_location: 'registro' });
      }
      if (kind === 'pump') countPump(1, true); // a foto pega o visor já parado
      var art = props[kind].querySelector('.sim__art').firstElementChild.cloneNode(true);
      var defs = art.querySelector('defs');
      if (defs) defs.parentNode.removeChild(defs); // os gradientes do original continuam valendo
      view.innerHTML = '';
      view.appendChild(art);
      var txt = T('read')[kind];
      statusT.textContent = txt[0];
      pill.textContent = fuel ? SIM.pt.val.fuel : SIM.pt.val.odo; // a tela do app é em português
      cam.className = 'sim__cam';
      box.removeAttribute('style');
      pill.removeAttribute('style');
      screen.classList.add('is-cam');
      var d = quick ? { focus: 0, scan: 0, lock: 0, read: 60, close: 1000, next: 1500 }
                    : { focus: 380, scan: 640, lock: 1450, read: 1950, close: 3050, next: 3650 };
      later(function () { cam.classList.add('is-focus'); }, d.focus);
      if (!quick) later(function () { cam.classList.add('is-scan'); }, d.scan);
      later(function () {
        // os cantos travam no que foi lido: o visor do hodômetro ou os campos da bomba/comprovante
        var r = union(kind === 'odo' ? [art.querySelector('.gauge__lcd')] : art.querySelectorAll('.sim-ocr'));
        var c = cam.getBoundingClientRect(), pad = c.width * .035;
        if (!r || !c.width) return;
        box.style.left = (r.l - c.left - pad) + 'px';
        box.style.top = (r.t - c.top - pad) + 'px';
        box.style.width = (r.r - r.l + pad * 2) + 'px';
        box.style.height = (r.b - r.t + pad * 2) + 'px';
        pill.style.left = ((r.l + r.r) / 2 - c.left) + 'px';
        pill.style.top = (r.t - c.top - pad * 2) + 'px';
      }, d.lock);
      later(function () {
        cam.classList.add('is-read');
        statusT.textContent = txt[1];
        props[kind].classList.add('is-used');
        setShot(fuel ? 3 : 1);
        setStep(fuel ? 'fuel-read' : 'odo-read');
        hint.textContent = txt[1] + ': ' + T('val')[fuel ? 'fuel' : 'odo'];
      }, d.read);
      later(function () {
        screen.classList.remove('is-cam');
        busy = false;
        sim.classList.remove('is-busy');
      }, d.close);
      later(function () { advance(fuel ? 'review' : 'fuel'); }, d.next);
    };
    var advance = function (to) {
      if (busy || (to === 'fuel' && step !== 'odo-read') || (to === 'review' && step !== 'fuel-read')) return;
      press(to === 'fuel' ? '[data-hot="next"]' : '[data-hot="review"]');
      setShot(to === 'fuel' ? 2 : 4, 'push');
      setStep(to);
      if (to === 'fuel') countPump(1);
      armIdle();
    };
    var save = function () {
      if (busy || step !== 'review') return;
      secs = Math.max(1, Math.round((performance.now() - t0) / 1000));
      setShot(5, 'dismiss');
      setStep('saved');
      // Baixar / Fazer de novo têm de aparecer: se ficaram abaixo da dobra, a página sobe só o que falta
      later(function () {
        var r = foot.getBoundingClientRect(), gap = r.bottom - window.innerHeight + 20;
        if (gap > 0 && r.top - gap > 0) window.scrollBy({ top: gap, behavior: quick ? 'auto' : 'smooth' });
      }, quick ? 0 : 420);
      track('site_interaction', { event_category: 'ui', event_label: 'sim_saved', event_location: 'registro', value: secs });
    };
    // O objeto voa até a tela (de onde estiver: parado ou no meio do arrasto) e some nela
    var send = function (b, kind, dx, dy) {
      if (busy) return;
      busy = true;
      sim.classList.add('is-busy');
      clearIdle();
      if (quick) { b.style.transform = ''; scan(kind); return; }
      var ar = b.querySelector('.sim__art').getBoundingClientRect(), sr = screen.getBoundingClientRect();
      var tx = dx + (sr.left + sr.width / 2) - (ar.left + ar.width / 2);
      var ty = dy + (sr.top + sr.height * .5) - (ar.top + ar.height / 2);
      var from = b.style.transform || 'none';
      b.classList.add('is-fly');
      var fly = b.animate([
        { transform: from, opacity: 1 },
        { transform: 'translate(' + tx.toFixed(1) + 'px,' + ty.toFixed(1) + 'px) scale(.22)', opacity: 0 }
      ], { duration: 460, easing: 'cubic-bezier(.5, 0, .75, .3)', fill: 'forwards' });
      fly.onfinish = function () {
        b.style.transform = '';
        b.classList.remove('is-fly');
        b.classList.add('is-used');
        fly.cancel();
        b.querySelector('.sim__art').animate({ opacity: [0, 1] }, { duration: 600, easing: 'ease-out' });
        screen.parentNode.animate({ transform: ['none', 'scale(1.012)', 'none'] }, { duration: 320, easing: 'ease-out' });
        scan(kind);
      };
    };
    var reset = function () {
      timers.forEach(clearTimeout);
      timers = [];
      busy = false;
      t0 = 0;
      sim.classList.remove('is-busy');
      screen.classList.remove('is-cam');
      Object.keys(props).forEach(function (k) { props[k].classList.remove('is-used'); props[k].style.transform = ''; });
      countPump(0);
      setShot(0);
      setStep('odo');
      armIdle();
    };

    // Arrastar: segue o dedo/cursor (inclina com a velocidade); solto em cima do celular = lê
    var drag = null, suppress = false;
    var overPhone = function (x, y) {
      var r = screen.getBoundingClientRect();
      return x > r.left - 24 && x < r.right + 24 && y > r.top - 24 && y < r.bottom + 24;
    };
    Object.keys(props).forEach(function (k) {
      var b = props[k];
      b.addEventListener('pointerdown', function (e) {
        suppress = false;
        if (busy || b.getAttribute('aria-disabled') === 'true' || e.button > 0) return;
        drag = { id: e.pointerId, x: e.clientX, y: e.clientY, lx: e.clientX, vx: 0, dx: 0, dy: 0, moved: false };
        try { b.setPointerCapture(e.pointerId); } catch (err) { /* sem captura */ }
      });
      b.addEventListener('pointermove', function (e) {
        if (!drag || e.pointerId !== drag.id) return;
        drag.dx = e.clientX - drag.x;
        drag.dy = e.clientY - drag.y;
        if (!drag.moved && Math.abs(drag.dx) + Math.abs(drag.dy) < 6) return;
        if (!drag.moved) {
          drag.moved = true;
          b.classList.add('is-drag');
          sim.classList.add('is-dragging');
          clearIdle();
        }
        drag.vx = drag.vx * .8 + (e.clientX - drag.lx) * .2;
        drag.lx = e.clientX;
        b.style.transform = 'translate(' + drag.dx.toFixed(1) + 'px,' + drag.dy.toFixed(1) + 'px) rotate(' + clamp(drag.vx * 1.4, -14, 14).toFixed(1) + 'deg)';
        sim.classList.toggle('is-over', overPhone(e.clientX, e.clientY));
      });
      var end = function (e) {
        if (!drag || e.pointerId !== drag.id) return;
        var d = drag;
        drag = null;
        sim.classList.remove('is-dragging', 'is-over');
        if (!d.moved) return; // vira clique
        suppress = true;
        b.classList.remove('is-drag');
        if (e.type === 'pointerup' && overPhone(e.clientX, e.clientY)) { send(b, k, d.dx, d.dy); return; }
        // volta para o lugar
        var from = b.style.transform;
        b.style.transform = '';
        if (!quick) b.animate({ transform: [from, 'none'] }, { duration: 520, easing: OUT });
        armIdle();
      };
      b.addEventListener('pointerup', end);
      b.addEventListener('pointercancel', end);
      b.addEventListener('click', function (e) {
        if (suppress && e.detail) { suppress = false; return; }
        suppress = false;
        if (b.getAttribute('aria-disabled') !== 'true') send(b, k, 0, 0);
      });
    });
    sim.querySelector('[data-hot="scan"]').addEventListener('click', function () {
      if (step === 'odo') send(props.odo, 'odo', 0, 0);
      else if (step === 'fuel') send(props.pump, 'pump', 0, 0);
    });
    sim.querySelector('[data-hot="next"]').addEventListener('click', function () { advance('fuel'); });
    sim.querySelector('[data-hot="review"]').addEventListener('click', function () { advance('review'); });
    sim.querySelector('[data-hot="save"]').addEventListener('click', save);
    sim.querySelector('[data-sim-again]').addEventListener('click', function () {
      reset();
      track('site_interaction', { event_category: 'ui', event_label: 'sim_again', event_location: 'registro' });
    });

    // Na carga: tela do passo 1, bomba zerada. Ao aparecer: ignição do hodômetro e o chamado.
    countPump(0);
    setShot(0);
    setStep('odo');
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries, obs) {
        if (!entries[0].isIntersecting) return;
        sim.classList.add('is-on');
        armIdle();
        obs.disconnect();
      }, { threshold: .5 }).observe(props.odo);
    } else sim.classList.add('is-on');
  })();

  // Estrada (abertura dos Recursos): faixas do meio em perspectiva. Cada faixa está a uma
  // distância z (1 = perto); na tela, y = 400/z e a largura encolhe junto. A rolagem anda com a
  // moto: z diminui, a faixa desce e cresce; a que passa por baixo volta lá no horizonte.
  var road = document.querySelector('.ride__road');
  var roadDash = road ? Array.prototype.slice.call(road.querySelectorAll('.ride__dash polygon')) : [];
  var drawRoad = function (o) {
    var P = 1.4, n = roadDash.length, span = n * P;
    roadDash.forEach(function (poly, i) {
      var z = 1 + ((i * P - o) % span + span) % span;
      var ya = 400 / z, yb = 400 / (z + .6), wa = 8 * ya / 400, wb = 8 * yb / 400;
      poly.setAttribute('points', (500 - wa).toFixed(1) + ',' + ya.toFixed(1) + ' ' + (500 + wa).toFixed(1) + ',' + ya.toFixed(1) + ' ' +
        (500 + wb).toFixed(1) + ',' + yb.toFixed(1) + ' ' + (500 - wb).toFixed(1) + ',' + yb.toFixed(1));
    });
  };
  var manifesto = document.querySelector('.manifesto');
  var rail = document.querySelector('[data-rail]');
  var railTrack = rail && rail.querySelector('.badge-grid');

  var frame = function () {
    var y = window.scrollY, vh = window.innerHeight;
    if (capsule) {
      var fuelMax = document.documentElement.scrollHeight - vh;
      capsule.style.setProperty('--fuel', clamp(fuelMax > 0 ? y / fuelMax : 0, 0, 1).toFixed(4));
      var chap = '';
      // o rótulo do capítulo fica oculto (sem eyebrow na página): mede pelo bloco do título
      chapters.forEach(function (c) { if ((c.hidden ? c.parentElement : c).getBoundingClientRect().top < vh * .5) chap = chapterText(c); });
      var head = document.querySelector('#recursos [data-chapter]');
      var sub = function (box, kicker) {
        var b = box.getBoundingClientRect();
        if (b.top <= vh * .5 && b.bottom >= vh * .5) chap = (head ? head.textContent.trim() + ' · ' : '') + kicker.textContent.trim();
      };
      if (sim) sub(sim, sim.querySelector('.kicker'));
      if (reel && reelActive >= 0) sub(reel, feats[reelActive].querySelector('.kicker'));
      setChapter(chap);
    }
    if (!motion) return;

    if (heroPhone && y < vh * 2) {
      // Pelo topo do palco (sem a inclinação): deitado com o topo a 75% da tela, em pé a 12%
      var vt = heroVisual.getBoundingClientRect().top;
      heroPhone.style.setProperty('--tilt', ease(clamp((vt - vh * .12) / (vh * .63), 0, 1)).toFixed(3));
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
    if (road && inView(road)) drawRoad(y * .012);
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
  var markW = window.innerWidth;
  window.addEventListener('resize', function () {
    if (window.innerWidth === markW) return; // barra do Safari: só a altura muda
    markW = window.innerWidth;
    fitMark();
  }, { passive: true });
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
