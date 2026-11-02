// Layout check for the concept drawing (docs/site/index.html, built by build.py).
// Paste into the DevTools console of the served page (or evaluate it over CDP). It visits every
// scene and reports, per scene, lit text that overlaps other text, is crossed by a line, sticks
// out of a box, or collides with a pill. Expected result: {} (it also logs "no overlaps").
// Heuristic: it relies on draw.py's class names (lbl, card, tag, val, st, railtag ...).
(async () => {
  await document.fonts.ready;
  const svg = document.querySelector('#cd');
  const scenes = ['overview', ...[...document.querySelectorAll('.picker button')].map(b => b.dataset.scene).filter(s => s !== 'overview')];
  const visible = el => { for (let e = el; e && e !== svg; e = e.parentNode) if (getComputedStyle(e).display === 'none') return false; return true; };
  const group = el => el.closest('#cd > g, #cd > rect, #cd > text') || el;
  const inter = (a, b, m = 0) => a.x + m < b.x + b.width && b.x + m < a.x + a.width && a.y + m < b.y + b.height && b.y + m < a.y + a.height;
  const res = {};
  for (const sc of scenes) {
    location.hash = '#' + sc; window.dispatchEvent(new PopStateEvent('popstate'));
    await new Promise(r => setTimeout(r, 60));
    const focus = svg.classList.contains('focus');
    const important = g => !focus || g.classList.contains('on') || g.classList.contains('step') || g.classList.contains('badge') || !g.hasAttribute('data-layer');
    const texts = [...svg.querySelectorAll('text')].filter(visible).filter(t => t.textContent.trim() && !t.closest('.band, rect.band') && !['bh','bsub'].includes(t.getAttribute('class')))
      .map(t => ({ t, g: group(t), b: t.getBBox(), s: t.textContent }));
    const issues = [];
    // text vs text
    for (let i = 0; i < texts.length; i++) for (let j = i + 1; j < texts.length; j++) {
      const A = texts[i], B = texts[j];
      if (A.g === B.g) continue;
      if (!important(A.g) && !important(B.g)) continue;
      if (inter(A.b, B.b, -2)) issues.push(`TT "${A.s}" x "${B.s}" @${Math.round(A.b.x)},${Math.round(A.b.y)}`);
    }
    // line through text (lines from other groups), skip text with halo (.lbl) unless crossing is long
    const lines = [...svg.querySelectorAll("path.ln")].filter(visible);
    for (const T of texts) {
      if (!important(T.g)) continue;
      if (['stn','valt','railt'].includes(T.t.getAttribute('class'))) continue;
      const bb = { x: T.b.x + 1, y: T.b.y + 2, width: T.b.width - 2, height: T.b.height - 4 };
      for (const p of lines) {
        const g = group(p);
        if (g === T.g) continue;
        if (!important(g) && T.t.classList.contains('lbl')) continue;
        const L = p.getTotalLength(); let hits = 0;
        for (let d = 0; d <= L; d += 2) { const q = p.getPointAtLength(d); if (q.x > bb.x && q.x < bb.x + bb.width && q.y > bb.y && q.y < bb.y + bb.height) hits++; }
        if (hits) issues.push(`TL "${T.s}" crossed by ${g.getAttribute('data-layer')||'?'} line (${hits}) @${Math.round(T.b.x)},${Math.round(T.b.y)}`);
      }
    }
    // text sticking out of a card / mux / tag it belongs to or crosses
    const boxes = [...svg.querySelectorAll('rect.card, rect.railtag, rect.val, rect.st')].filter(visible);
    for (const T of texts) {
      if (!important(T.g)) continue;
      for (const r of boxes) {
        const rb = r.getBBox();
        if (!inter(T.b, rb, 0.5)) continue;
        const inside = T.b.x >= rb.x - 0.5 && T.b.x + T.b.width <= rb.x + rb.width + 0.5 && T.b.y >= rb.y - 0.5 && T.b.y + T.b.height <= rb.y + rb.height + 0.5;
        if (!inside && !(r.matches('rect.card') && ['stn'].includes(T.t.getAttribute('class')))) issues.push(`TB "${T.s}" crosses ${r.getAttribute('class')} of "${group(r).textContent.trim().slice(0,20)}" @${Math.round(T.b.x)},${Math.round(T.b.y)}`);
      }
    }
    const pills = [...svg.querySelectorAll('path.tag')].filter(visible).map(p => ({ p, g: group(p), b: p.getBBox() }));
    for (const P of pills) {
      if (!important(P.g)) continue;
      for (const T of texts) if (T.g !== P.g && important(T.g) && inter(T.b, P.b, -2)) issues.push(`PT pill "${P.g.textContent.trim()}" near text "${T.s}" @${Math.round(P.b.x)},${Math.round(P.b.y)}`);
      const bb = { x: P.b.x + 1, y: P.b.y + 1, width: P.b.width - 2, height: P.b.height - 2 };
      for (const l of lines) {
        const g = group(l);
        if (g === P.g || !important(g)) continue;
        const L = l.getTotalLength(); let hits = 0;
        for (let d = 0; d <= L; d += 2) { const q = l.getPointAtLength(d); if (q.x > bb.x && q.x < bb.x + bb.width && q.y > bb.y && q.y < bb.y + bb.height) hits++; }
        if (hits) issues.push(`PL pill "${P.g.textContent.trim()}" crossed by ${g.getAttribute('data-layer')} line @${Math.round(P.b.x)},${Math.round(P.b.y)}`);
      }
    }
    if (issues.length) res[sc] = [...new Set(issues)];
  }
  location.hash = '#overview'; window.dispatchEvent(new PopStateEvent('popstate'));
  console.log(Object.keys(res).length ? res : "no overlaps");
  return res;
})()
