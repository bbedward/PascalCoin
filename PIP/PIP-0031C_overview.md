# PIP-0031C Flutter Wallet

Full PIP: https://github.com/bbedward/PascalCoin/blob/b97dc8c2baa768928c39735ed477bae0f08b3f68/PIP/PIP-0031C.md

## Overview
As crypto is becoming more mainstream, it is crucial to make the experience intuitive, easy to understand, and secure for everyone. Over 2.5 billion people own smartphones and tablets today, making it by far the most important platform for reaching wide audiences. We're proposing a wallet developed with Flutter, which will provide a native experience and performance to both Android and iOS users. Unlike any kind of web app or any other cross platform framework - flutter apps are AOT compiled into native arm/arm64 code and perform significantly better as a result. There's also options to run these apps on desktop platforms - with Flutter Desktop Embedding under active development in official Flutter repos, and [go-flutter](https://github.com/go-flutter-desktop/go-flutter) is an alternative that supports Linux, MacOS, and Windows.

All signing operations will occur on device, a library in Dart will be developed for these low-level PascalCoin operations. Private keys will never be transmitted to the server.

## Deliverables:
1) UI & UX research/exploration and initial sketches.
2) Sketches and user flow schematics of the whole UI.
3) Develop interface in Flutter based on sketches and user flow schematics.
4) Finish implementation of all essential wallet operations, signing library implemented in dart. 
5) Launch iOS testflight and Android beta on the play store.
6) Implementation of the python server with websocket APIs, providing price data and other extras.
7) Submit initial release to the Google Play store and iOS App Store
8) (Optional) Desktop support. This is accomplished by making various alterations to both the interface and the code to run on desktop. Some such changes would include requiring a different storage backend, disabling various mobile-only features such as QR scanning, etc.

## Timeline (represents cumulative time):
* Completion of deliverable #1: 7 days
* Completion of deliverable #2: 17 days
* Completion of deliverable #3: 35 days
* Completion of deliverable #4 and #5: 60 days
* Completion of deliverable #6: 75 days
* Completion of deliverable #7: 75-90 days (varies on app store review)
* Completition of deliverable #8: 90-100days

Total time: 90-100 days.

## Payment Schedule:
* $3500: Upon completion of (1)
* $3500: Upon completion of (2)
* $4000: Upon completion of (3)
* $5000: Upon completion of (4) and (5)
* $4000: Upon completion of (6)
* (Optional) $5000: Upon completion of (8)

Total: $20,000-$25,000

## Licensing

All software developed as part of this proposal will be released under the [MIT License](https://opensource.org/licenses/MIT).

Artwork, animations, and other assets that are created by us for this proposal will be released under the [CC0](https://creativecommons.org/share-your-work/public-domain/cc0/) license.

## Distribution

The application will be distributed by us on the Google Play Store and the iOS App Store. The organization registered with the iOS App Store is "Avenge Media LLC" which is an entity we own that is based in the United States, applications will be released under the brand "Appditto" on the Google Play Store.

Desktop distribution will occur through standard binaries. Other app store distribution (such as the MacOS app store) is "to be determined"

## Background

We encourage you to check out some other applications, websites, etc. that have been developed and designed by us. These are listed below:

| Link | Description |
| :----- | :------ |
[natrium.io](https://natrium.io) | NANO Wallet, developed with Flutter. Available on the iOS App Store and Google Play Store (Open Source)
[kalium.banano.cc](https://kalium.banano.cc) | BANANO Wallet, developed with Flutter. Available on the iOS App Store and Google Play Store (Open Source)
[Natrium/Kalium Server](https://github.com/appditto/natrium-wallet-server) | Natrium and Kalium server. Websocket server developed Python/asyncio (aiohttp+uvloop) (Open Source)
[monkeytalks.cc](https://monkeytalks.cc) | Monkey Talks - open source on-chain chat and faucet for BANANO developed with Vue and Python (Open Source)
[nanopaperwallet.com](https://nanopaperwallet.com) | Paper wallet generator for NANO (Open Source)
[bananominer.com](https://bananominer.com) | folding@home faucet for BANANO
[banano.cc](https://banano.cc) | BANANO's website
[appditto.com](https://appditto.com) | Appditto website
[animations](https://www.2dimensions.com/a/yekta/files/recent/all) | Various flare animations created by us