Note: requires "Show and Tell" flair. Weekly self-promo thread is the safer route, check pinned post first.

Title: Bugle, a plain RSS/Atom reader, iOS + macOS + watchOS

Body: Built a feed reader that only does one thing: pulls RSS and Atom feeds into one timeline, newest first. Used Foundation's XMLParser directly for both formats since a lot of readers silently fail on one or the other. SwiftUI throughout, a watchOS companion target with no iOS host pairing, and a local `FeedStore` with no server sync since a feed list is personal state with no reason to leave the device. $0.99 on the App Store, free on the web. Happy to talk through any of the feed-parsing edge cases.

https://bugle.jaybulb.com
