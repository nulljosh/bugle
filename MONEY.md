# Bugle Money

How Bugle makes money. The fleet-wide ledger is `GTM.md` in the Code root.

## Price

$0.99 upfront on the App Store.

## Rail

App Store paid download. Apple keeps 15%, so each sale pays out $0.84.

## Why

RSS readers sell as paid tools. No feed server of ours to fund, so no subscription. The web version stays free, so the landing page is the trial and the store is the checkout.

## Next

Nothing to build. Watch App Store Connect sales. If a month passes with installs on the web and none in the store, go back to free.

## Change it

`asc pricing schedule create --app 6787759999 --price 0.99 --base-territory USA --start-date YYYY-MM-DD`. Swap `--price 0.99` for `--free` to revert. No build, no review.

Anyone who got Bugle while it was free keeps it free. Only new customers pay.

*ASC 6787759999. Set 2026-09-20.*
