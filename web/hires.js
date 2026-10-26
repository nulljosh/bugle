// The lead story's picture at full size. Feeds send small copies (BBC 240 px, the Guardian 460, CBC 620) and the hero
// is a phone-wide card. Picture servers that size by URL take a bigger size; the Guardian signs its URLs, so its widest
// plain copy comes from the story's own page (through /feed). Mirrors HiRes.swift.
var HiRes = (function () {
  function upsize(u) {
    return (u || '').replace(/ichef\.bbci\.co\.uk\/(ace\/\w+|news)\/\d+\//, 'ichef.bbci.co.uk/$1/1536/')
      .replace(/ichef\.bbci\.co\.uk\/images\/ic\/\d+x\d+\//, 'ichef.bbci.co.uk/images/ic/1200x1200/')   // podcast art
      .replace(/Resize(%3D|=)\d+/, 'Resize$11600')                                                        // CBC
      .replace(/(a57\.foxnews\.com\/.+?)\/\d+\/\d+\//, '$1/1600/900/')                                  // Fox
      .replace(/([?&](?:#038;)?w=)\d+/, '$11600');                                                       // WordPress: NY Post, Postmedia
  }
  function width(s) { var m = /width=(\d+)/.exec(s); return m ? +m[1] : 0; }
  function widest(list) { return list.reduce(function (a, b) { return width(b) > width(a || '') ? b : a; }, null); }

  // Swap the picture for the big copy once it has loaded, so the small one shows meanwhile and nothing flashes.
  function sharpen(img, e) {
    var swap = function (u) { if (!u || u === img.src) return; var big = new Image(); big.referrerPolicy = 'no-referrer'; big.onload = function () { img.src = u; }; big.src = u; };
    if (!/^https:\/\/i\.guim\.co\.uk\//.test(e.image || '')) return swap(upsize(e.image));
    var stem = e.image.split('?')[0];
    fetch('/feed?url=' + encodeURIComponent(e.url)).then(function (r) { return r.ok ? r.text() : ''; }).then(function (html) {
      swap(widest((html.match(/https:\/\/i\.guim\.co\.uk\/img\/[^"\s]+/g) || []).map(function (s) { return s.replace(/&amp;/g, '&'); })
        .filter(function (s) { return s.indexOf(stem) === 0 && s.indexOf('fit=max') > 0 && s.indexOf('overlay') < 0; })));
    }).catch(function () {});
  }
  return { upsize: upsize, widest: widest, sharpen: sharpen };
})();
