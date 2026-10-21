# Kindred reference redesign

Flutter implementation: `mobile/lib/theme.dart`, `widgets.dart`, `main.dart`, `screens.dart`.
The attached reference is the visual source. Existing licensed demo portraits remain in use.
Native Flutter uses KindredColors and ThemeData; CSS tokens are a portable reference, with no Tailwind dependency.

## Profile card
White surface, 24 px corners, soft 24 px shadow, 14 px padding. Portrait ratio 1.02 with 18 px corners. Name and age below the portrait, then work and distance. Name and photo open the detail route. Menu exposes safety actions. Verification has a tooltip. Card stays scrollable on short phones.

## Discovery actions
49 px outer circles, 72 px central circles. Star opens prompt composer, cross passes with undo, heart opens photo composer, bolt opens preferences. Material buttons provide hover, focus, pressed feedback and semantic tooltips. Actions stay above navigation while the profile scrolls.

## Header and drawer
88 px toolbar; initial avatar opens a 310 px drawer. Drawer links to likes, messages, preferences and settings. Updated name is shared with profile editor. Dismiss through back, scrim, swipe or selecting an item.

## Detail route
Rounded portrait, name, location, About, demo interests and Sunday prompt. Photo and prompt likes open the existing comment composer. Back returns to discovery. Safety actions remain available.

## Navigation and supporting states
Four Material navigation destinations with visible labels and selected state. White backgrounds, dark sans serif headings, muted secondary text, blush supporting panels. Existing empty discovery, paused profile, empty likes and chats, validation and image fallback remain available. Sheets scroll above the keyboard.
