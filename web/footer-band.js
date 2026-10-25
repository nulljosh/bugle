// Footer band: Bugle's things in a row (the mark, a bugle, a newspaper, a feed, a globe, a bookmark), cut like a line
// engraving in plain 2D canvas. Faint rules run across the band; inside the glyphs they thicken, and thicken again on
// the edge facing away from the light, so the glyphs look cut into the page. Drawn once per size and theme.
// Same engraving as the Hermes landing (hermes/landing/footer-band.js); only the glyphs differ.
(function () {
  var band = document.querySelector('.word-band'), canvas = band && band.querySelector('canvas');
  if (!canvas) return;

  // Each glyph is drawn white on a 100 unit square.
  var GLYPHS = [
    function (c) { // the mark: three feeds merging into one line (mark.svg at 1/10 scale)
      c.lineWidth = 9; c.lineCap = 'round'; c.beginPath();
      c.moveTo(18, 28); c.bezierCurveTo(38, 28, 38, 50, 58, 50);
      c.moveTo(18, 50); c.lineTo(58, 50);
      c.moveTo(18, 72); c.bezierCurveTo(38, 72, 38, 50, 58, 50);
      c.moveTo(58, 50); c.lineTo(84, 50); c.stroke();
    },
    function (c) { // bugle: mouthpiece, a straight lead pipe, one coil above it, a wide flared bell
      c.fillRect(6, 59, 7, 10);
      c.lineWidth = 6; c.beginPath(); c.moveTo(12, 64); c.lineTo(60, 64); c.stroke();
      c.beginPath(); c.ellipse(38, 46, 20, 15, 0, 0, 7); c.stroke();
      c.beginPath(); c.moveTo(56, 60); c.quadraticCurveTo(80, 58, 94, 38); c.lineTo(94, 90); c.quadraticCurveTo(80, 70, 56, 68); c.closePath(); c.fill();
    },
    function (c) { // newspaper: masthead bar and two columns cut out of the page
      c.beginPath(); c.roundRect(16, 20, 68, 60, 4); c.fill();
      c.globalCompositeOperation = 'destination-out';
      c.fillRect(22, 27, 56, 9);
      for (var y = 42; y <= 70; y += 7) { c.fillRect(22, y, 24, 3); c.fillRect(54, y, 24, 3); }
      c.globalCompositeOperation = 'source-over';
    },
    function (c) { // feed: a dot and two waves
      c.beginPath(); c.arc(26, 74, 8, 0, 7); c.fill();
      c.lineWidth = 10; c.lineCap = 'round';
      [28, 48].forEach(function (r) { c.beginPath(); c.arc(22, 78, r, -Math.PI / 2, 0); c.stroke(); });
    },
    function (c) { // globe: the world's news
      c.lineWidth = 6;
      c.beginPath(); c.arc(50, 50, 32, 0, 7); c.stroke();
      c.beginPath(); c.ellipse(50, 50, 13, 32, 0, 0, 7); c.stroke();
      c.beginPath(); c.moveTo(18, 50); c.lineTo(82, 50); c.moveTo(24, 34); c.lineTo(76, 34); c.moveTo(24, 66); c.lineTo(76, 66); c.stroke();
    },
    function (c) { // bookmark: saved for later
      c.beginPath(); c.moveTo(32, 16); c.lineTo(68, 16); c.lineTo(68, 86); c.lineTo(50, 70); c.lineTo(32, 86); c.closePath(); c.fill();
    }
  ];
  // Lays the glyphs out evenly across a w by h 2D context, in the given colour: one row, or two on a narrow band.
  function grid(w, h) {
    var n = GLYPHS.length, rows = w < h * 3 ? 2 : 1, per = Math.ceil(n / rows);
    return { rows: rows, per: per, cell: Math.min(h / rows * 0.86, w / per) };
  }
  function paint(c, w, h, colour) {
    var g = grid(w, h), gap = (w - g.cell * g.per) / g.per, rowH = h / g.rows;
    GLYPHS.forEach(function (draw, i) {
      var col = i % g.per, row = Math.floor(i / g.per);
      c.save(); c.translate(gap / 2 + col * (g.cell + gap), row * rowH + (rowH - g.cell) / 2 + rowH * 0.04); c.scale(g.cell / 100, g.cell / 100);
      c.fillStyle = c.strokeStyle = colour; draw(c); c.restore();
    });
  }

  var ctx = canvas.getContext('2d');
  if (!ctx) return;
  function layer(w, h) { var c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
  // Horizontal rules `t` px thick, one every `pitch` px, kept only where `mask` is drawn (everywhere when null).
  function rules(w, h, pitch, t, colour, mask) {
    var c = layer(w, h), x = c.getContext('2d');
    x.fillStyle = colour;
    for (var y = 0; y < h; y += pitch) x.fillRect(0, Math.round(y + (pitch - t) / 2), w, Math.max(1, Math.round(t)));
    if (mask) { x.globalCompositeOperation = 'destination-in'; x.drawImage(mask, 0, 0); }
    return c;
  }
  var drawnW = 0;
  function draw() {
    var dpr = Math.min(window.devicePixelRatio || 1, 2), w = Math.round(canvas.clientWidth * dpr), h = Math.round(canvas.clientHeight * dpr);
    if (!w || !h) return;
    drawnW = w; canvas.width = w; canvas.height = h;
    var colour = getComputedStyle(band).color, pitch = Math.min(5 * dpr, Math.max(3 * dpr, grid(w, h).cell / 22)), s = Math.max(2, h * 0.014);
    var glyphs = layer(w, h); paint(glyphs.getContext('2d'), w, h, '#fff');
    // the shadow side: glyph pixels whose neighbour down and right is outside the glyph (light from the top left)
    var shade = layer(w, h), sc = shade.getContext('2d');
    sc.drawImage(glyphs, 0, 0); sc.globalCompositeOperation = 'destination-out'; sc.drawImage(glyphs, -s, -s);
    ctx.globalAlpha = 0.28; ctx.drawImage(rules(w, h, pitch, dpr * 0.75, colour, null), 0, 0);
    ctx.globalAlpha = 1; ctx.drawImage(rules(w, h, pitch, pitch * 0.32, colour, glyphs), 0, 0);
    ctx.drawImage(rules(w, h, pitch, pitch * 0.6, colour, shade), 0, 0);
    // fade out toward the legal line
    var g = ctx.createLinearGradient(0, h * 0.88, 0, h);
    g.addColorStop(0, '#000'); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.globalCompositeOperation = 'destination-in'; ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = 'source-over';
  }
  band.classList.add('live');
  draw();
  // iOS fires resize as the toolbar slides; only a width change needs a redraw
  window.addEventListener('resize', function () { if (Math.round(canvas.clientWidth * Math.min(window.devicePixelRatio || 1, 2)) !== drawnW) draw(); });
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', draw);
})();
