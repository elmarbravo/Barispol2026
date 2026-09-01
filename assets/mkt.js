/* ─────────────────────────────────────────────────────────────
   MARKETING — Centro Médico Barispol
   Meta Pixel 1052013565482332 e eventos de contacto.

   Este ficheiro é a única fonte do píxel. Para o activar numa
   página, basta uma linha antes de </body>:

       <script src="assets/mkt.js"></script>

   ATENÇÃO — categoria sensível
   Saúde é categoria sensível na Meta desde Janeiro de 2025. A Meta
   desactiva, sem aviso, eventos, públicos e conversões cujo nome
   sugira uma condição de saúde. Por isso os serviços são
   identificados por código neutro e a legenda vive aqui, em
   comentário, nunca no que sai para a Meta.

       servico_00  contacto geral
       servico_01  ecografia obstétrica
       servico_02  ecografia pélvica e ginecológica
       servico_03  ecografia abdominal
       servico_04  ecografia mamária
       servico_05  ecografia da tiroide
       servico_06  ecografia renal e das vias urinárias
       servico_07  raio-X
       servico_10  análises clínicas
       servico_11  consulta de clínica geral
       servico_12  pediatria
       servico_13  ginecologia

   Nunca criar um evento «ecografia_obstetrica», um público
   «gravidas_luanda» ou uma conversão «marcacao_mama».
   ───────────────────────────────────────────────────────────── */
(function (w, d) {
  'use strict';

  var PIXEL_ID = '1052013565482332';

  /* Meta Pixel base */
  !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
  n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;
  n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;
  t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}
  (w,d,'script','https://connect.facebook.net/en_US/fbevents.js');

  w.fbq('init', PIXEL_ID);
  w.fbq('track', 'PageView');

  function track(evt, params) {
    if (typeof w.fbq === 'function') {
      try { w.fbq('track', evt, params); } catch (e) { /* silencioso */ }
    }
  }
  w.barispolTrack = track;

  /* Eventos de contacto.
     Apanha sozinho qualquer link wa.me, tel: ou mailto: da página.
     Para distinguir o serviço, acrescentar data-wa="servico_XX" ao link. */
  d.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    var href = a.getAttribute('href') || '';

    if (href.indexOf('wa.me') > -1 || href.indexOf('api.whatsapp.com') > -1) {
      track('Contact', {
        content_name: a.getAttribute('data-wa') || 'servico_00',
        content_category: 'whatsapp'
      });
    } else if (href.indexOf('tel:') === 0) {
      track('Contact', { content_name: 'telefone', content_category: 'chamada' });
    } else if (href.indexOf('mailto:') === 0) {
      track('Contact', { content_name: 'email', content_category: 'email' });
    }
  }, true);

  /* O formulário de contacto.html abre o WhatsApp por window.open,
     não por um link, portanto regista-se à parte. */
  d.addEventListener('submit', function (e) {
    if (e.target && e.target.id === 'formlead') {
      var s = d.getElementById('servico');
      var mapa = {
        'Análises clínicas': 'servico_10',
        'Consulta de clínica geral': 'servico_11',
        'Pediatria': 'servico_12',
        'Ginecologia e obstetrícia': 'servico_13',
        'Ecografia ou raio-X': 'servico_01',
        'Ainda não sei': 'servico_00'
      };
      track('Lead', {
        content_name: (s && mapa[s.value]) || 'servico_00',
        content_category: 'formulario'
      });
    }
  }, true);
})(window, document);
