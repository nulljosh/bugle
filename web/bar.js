// The story toolbar's title shows only once the headline has scrolled under the bar, like an iOS inline title: at
// the top of a story the bar is just back and the actions, and the headline below says what it is.
(function () {
  var bar = document.querySelector('.story-bar');
  function check() {
    var h = document.querySelector('#article h2');
    bar.classList.toggle('titled', !!h && h.getBoundingClientRect().bottom < bar.getBoundingClientRect().bottom);
  }
  addEventListener('scroll', check, { passive: true });
  addEventListener('hashchange', function () { bar.classList.remove('titled'); });
})();
