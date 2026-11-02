# Bugle Money

How Bugle makes money. The company plan is `REVENUE.md` in the Code root; the ledger is `GTM.md`.

## Price and rail

$0.99 upfront on the App Store (ASC 6787759999), iPhone, iPad and Mac. Apple keeps 15%, so each sale pays about $0.84. The web reader at bugle.jaybulb.com/read stays free. The web is the trial and the store is the checkout.

## What is actually sold

The reader: multi-feed RSS and Atom, coverage grouping, podcasts, a reading list. The stories belong to the publishers. Bugle reads their feeds and links back to them. The risk is that a publisher can block its feed or object to how it is shown. A paid Bugle must never sell their articles.

## Who pays and why

Someone who reads many sources and does not want an account, a feed to sign into or a subscription. One dollar, once, gets the reader. The web reader stays free for anyone who wants to try it first.

## Cost to serve

No paid API. Feeds are plain HTTP to each publisher. The CMS tables on the shared Supabase project are not wired into the app yet.

## Where we are

- 2026-10-25: renamed Coranto to Bugle. Apple refused the plain name for the store listing, so the listing carries a different name. GTM.md says Bugles, and the repo notes say Bugle News. Reconcile the two before the next submission.
- Repo notes (undated): iOS 2.0.0 is live, iOS 6.1.0 waits for review, and Mac 2.0.0 is in review.
- Revenue: no verified number (the App Store Connect key cannot read sales yet).

## Role in the company plan

Catalogue. GTM.md lists it as a $0.99 app that is free on the web. It serves Stage 0 as one of the dollar apps that prove strangers pay. Under Stage 2 it has to earn a place on the grid or be retired.

## Next

Once the Sales role is on the App Store Connect key, read the first month of Bugle sales against web reads. If the store earns nothing in a month, the price goes back to free.

## Million, billion, trillion

**A million.** Bugle is the reader people pick to keep up with the news in one place, paid once, with no feed server to fund.

**A billion.** Bugle is the default way to read the news on every Jaybulb device, and the publishers still get their readers.

**A trillion.** Bugle is the front door to the whole publishing web, and it sends readers back to the publishers instead of keeping them.

## Change it

`asc pricing schedule create --app 6787759999 --price 0.99 --base-territory USA --start-date YYYY-MM-DD`. Swap `--price 0.99` for `--free` to revert. No build, no review. Only with Joshua's yes in chat.

Anyone who got Bugle while it was free keeps it free.

*ASC 6787759999. Verified 2026-11-02.*
