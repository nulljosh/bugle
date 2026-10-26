// The default feeds: the news seeds, the local newsrooms by city and the default podcasts. Loaded before reader.js,
// which follows SEEDS on a first visit and adds PODCASTS once.
// ponytail: seed list mirrors FeedStore.seedFeeds and journalFeed in the app. Two copies beats
// standing up an API to serve 17 URLs; if it drifts, nothing breaks but the defaults.
var JOURNAL = { title: 'Journal', url: 'https://journal.jaybulb.com/feed.xml' };
var SEEDS = [
  ['CBC', 'https://www.cbc.ca/webfeed/rss/rss-topstories'],
  ['The Guardian', 'https://www.theguardian.com/world/rss'],
  ['NPR', 'https://feeds.npr.org/1001/rss.xml'],
  ['BBC', 'https://feeds.bbci.co.uk/news/world/rss.xml'],
  ['Global News', 'https://globalnews.ca/feed/'],
  ['NBC News', 'https://feeds.nbcnews.com/nbcnews/public/news'],
  ['Wall Street Journal', 'https://feeds.content.dowjones.io/public/rss/RSSWorldNews'],
  ['National Post', 'https://nationalpost.com/feed'],
  ['Fox News', 'https://moxie.foxnews.com/google-publisher/latest.xml'],
  ['NY Post', 'https://nypost.com/feed/'],
  ['NY Post Opinion', 'https://nypost.com/opinion/feed/'],
  ['Daily Wire', 'https://www.dailywire.com/feeds/rss.xml'],
  ['Vancouver Sun', 'https://vancouversun.com/feed'],
  ['The Province', 'https://theprovince.com/feed'],
  ['Hacker News', 'https://hnrss.org/frontpage'],
  ['Daring Fireball', 'https://daringfireball.net/feeds/main'],
  ['Wired', 'https://www.wired.com/feed/rss'],
  ['The Verge', 'https://www.theverge.com/rss/index.xml'],
  ['Ars Technica', 'https://feeds.arstechnica.com/arstechnica/index'],
  ['TechCrunch', 'https://techcrunch.com/feed/'],
  ['MacRumors', 'https://feeds.macrumors.com/MacRumors-All'],
  ['9to5Mac', 'https://9to5mac.com/feed/'],
  ['AppleInsider', 'https://appleinsider.com/rss/news/'],
  ['Macworld', 'https://www.macworld.com/feed'],
  ['Six Colors', 'https://sixcolors.com/feed/']
].map(function (f) { return { title: f[0], url: f[1] }; });

// Local newsrooms by city (Apple News and Ground News both have a Local feed). Mirrors FeedStore.local.
var LOCAL = [
  ['Vancouver', [['Vancouver Sun', 'https://vancouversun.com/feed'], ['The Province', 'https://theprovince.com/feed'], ['CBC British Columbia', 'https://www.cbc.ca/webfeed/rss/rss-canada-britishcolumbia'], ['Global BC', 'https://globalnews.ca/bc/feed/'], ['Vancouver Is Awesome', 'https://www.vancouverisawesome.com/rss']]],
  ['Calgary', [['Calgary Herald', 'https://calgaryherald.com/feed'], ['CBC Calgary', 'https://www.cbc.ca/webfeed/rss/rss-canada-calgary'], ['Global Calgary', 'https://globalnews.ca/calgary/feed/']]],
  ['Edmonton', [['Edmonton Journal', 'https://edmontonjournal.com/feed'], ['Global Edmonton', 'https://globalnews.ca/edmonton/feed/']]],
  ['Toronto', [['Toronto Sun', 'https://torontosun.com/feed'], ['CBC Toronto', 'https://www.cbc.ca/webfeed/rss/rss-canada-toronto'], ['Global Toronto', 'https://globalnews.ca/toronto/feed/']]],
  ['Ottawa', [['Ottawa Citizen', 'https://ottawacitizen.com/feed'], ['CBC Ottawa', 'https://www.cbc.ca/webfeed/rss/rss-canada-ottawa']]],
  ['Montreal', [['CBC Montreal', 'https://www.cbc.ca/webfeed/rss/rss-canada-montreal'], ['Global Montreal', 'https://globalnews.ca/montreal/feed/']]],
  ['Seattle', [['Seattle Times', 'https://www.seattletimes.com/seattle-news/feed/']]],
  ['New York', [['Gothamist', 'https://gothamist.com/feed'], ['NY Post Metro', 'https://nypost.com/metro/feed/']]],
  ['Los Angeles', [['LA Times California', 'https://www.latimes.com/california/rss2.0.xml'], ['LAist', 'https://laist.com/index.atom']]],
  ['London', [['BBC London', 'https://feeds.bbci.co.uk/news/england/london/rss.xml'], ['Evening Standard', 'https://www.standard.co.uk/news/london/rss']]]
].map(function (r) { return { city: r[0], feeds: r[1].map(function (f) { return { title: f[0], url: f[1] }; }) }; });

// The default shows (Joshua's own list, 2026-10-25). Mirrors FeedStore.podcasts.
var PODCASTS = [
  ['Wall Street Breakfast', 'https://www.spreaker.com/show/5725002/episodes/feed'],
  ["WSJ What's News", 'https://video-api.shdsvc.dowjones.io/api/podcasts/feed/the%20wall%20street%20journal%20whats%20news'],
  ['WSJ Tech News Briefing', 'https://video-api.shdsvc.dowjones.io/api/podcasts/feed/the%20wall%20street%20journal%20tech%20talk'],
  ['WSJ Your Money Briefing', 'https://video-api.shdsvc.dowjones.io/api/podcasts/feed/the%20wall%20street%20journals%20your%20money%20matters'],
  ['World Report', 'https://www.cbc.ca/podcasting/includes/wr.xml'],
  ['The Markets', 'https://feeds.megaphone.fm/GLD9322922848'],
  ['AI Daily: Claude News', 'https://media.rss.com/claude-ai-daily/feed.xml'],
  ['The AI Daily Brief', 'https://anchor.fm/s/f7cac464/podcast/rss'],
  ['The Philip DeFranco Show', 'https://feeds.megaphone.fm/AETTA1864906649'],
  ['Good Bad Billionaire', 'https://podcasts.files.bbci.co.uk/p0g7xj36.rss'],
  ['Deep Questions', 'https://rss.pdrl.fm/2d4b16/feeds.simplecast.com/_IjaDYAj'],
  ['My First Million', 'https://feeds.megaphone.fm/HS2300184645'],
  ['The Tim Dillon Show', 'https://audioboom.com/channels/5093219.rss'],
  ['The Mel Robbins Podcast', 'https://feeds.simplecast.com/UCwaTX1J']
].map(function (f) { return { title: f[0], url: f[1] }; });
