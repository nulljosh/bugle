// Short, clean list titles. Mirrors ios/Sources/Shared/Models/Headline.swift; change both or neither.
// variants() runs: the clean title, clause cuts longest first, then whole-word cuts. The list shows the first
// that fits on one line, so a title ends on a word, not "…". Classic script: sets globalThis.Headline.
(function () {
  var FILLER = new Set(['a', 'an', 'the', 'to', 'of', 'in', 'on', 'at', 'by', 'for', 'from', 'with', 'and', 'or',
    'but', 'as', 'is', 'are', 'was', 'his', 'her', 'its', 'their', 'after', 'amid', 'over',
    'vs', 'v', 'that', 'who', 'which', 'whose', 'other', 'how', 'what', 'when', 'where', 'why', 'into', 'up', 'about', 'than', 'this', 'these', 'those', 'your', 'my', 'our', 'be', 'has', 'have', 'had', 'will', 'would', 'can', 'could', 'not', 'no', 'more', 'most', 'very', 'just', '&', 'new', 'top', 'mr', 'mrs', 'ms', 'dr', 'sgt', 'gov', 'sen', 'rep', 'pres', 'gen', 'lt', 'col', 'capt', 'st', 'prof', 'u.s']);
  // Words that open a new phrase: a cut just before one ends on a whole idea.
  var PHRASE = new Set(['to', 'of', 'in', 'on', 'at', 'by', 'for', 'from', 'with', 'and', 'or', 'but', 'as', 'after', 'amid', 'over', 'that', 'who', 'which', 'whose', 'into', 'about', 'than', 'while', 'when', 'where', 'vs', 'because', 'before', 'during', 'until', 'against', 'without', 'under', 'near']);
  var SEPS = [': ', ' — ', ' – ', ' - ', ' | ', ', ', '; ', ' as ', ' after ', ' amid ', ' while ', ' but '];

  function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

  // A cut never ends on "to", "the", "of" or a dangling comma.
  function trimTail(s) {
    var words = s.trim().split(/\s+/).filter(Boolean);
    while (words.length > 1) {
      var last = words[words.length - 1].replace(/^[^\w]+|[^\w]+$/g, '').toLowerCase();
      if (FILLER.has(last) || !last) words.pop(); else break;
    }
    // a cut inside a quote keeps the quote, not its comma: 'loophole,' -> 'loophole'
    return words.join(' ').replace(/[\s,;:|\-–—]+$/, '').replace(/[,;:]+(['"’”]+)$/, '$1');
  }

  function clean(title, source) {
    var t = String(title || '').replace(/\s+/g, ' ').trim();
    t = t.replace(/^(opinion|analysis|watch|live|breaking|exclusive|update|video|explainer|editorial)\s*[:|\-–—]\s*/i, '');
    if (source) t = t.replace(new RegExp('\\s+[|\\-–—]\\s+(the\\s+)?' + escapeRe(source) + '(\\s+news)?\\s*$', 'i'), '');
    t = t.replace(/\s*[(\[][^)\]]*[)\]]/g, '');
    return trimTail(t);
  }

  function variants(title, source) {
    var full = clean(title, source), clauses = [];
    SEPS.forEach(function (sep) {
      var i = full.indexOf(sep);
      if (i < 0) return;
      var head = trimTail(full.slice(0, i));
      if (head.split(' ').length >= 3) clauses.push(head);   // "Show HN: ..." keeps its colon
    });
    var out = [full].concat(clauses.sort(function (a, b) { return b.length - a.length; }));
    // Word cuts come from the shortest clause, so a squeeze never drags the tail of the sentence back in.
    var words = out[out.length - 1].split(' ');
    // Cut only where the next word starts a new phrase ("cars | that put", "drivers | at greatest"), so a cut ends on
    // a whole idea; with no such break, any word will do.
    var bare = function (w) { return w.replace(/^[^\w]+|[^\w]+$/g, '').toLowerCase(); };
    var breaks = [];
    for (var k = 3; k < words.length; k++) if (PHRASE.has(bare(words[k]))) breaks.push(k);
    // phrase breaks first; plain word cuts after them, as the last resort for a narrow row
    var rest = [];
    for (var n = words.length - 1; n >= 2; n--) (breaks.indexOf(n) >= 0 ? out : rest).push(trimTail(words.slice(0, n).join(' ')));
    out = out.concat(rest);
    var seen = new Set();
    return out.filter(function (v) { return v && !seen.has(v) && seen.add(v); });
  }

  globalThis.Headline = { clean: clean, variants: variants };
})();
