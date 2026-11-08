# EzTongues

## Unreleased

- **Fixed:** the box's keybind no longer types its own letter into the box when it opens it.

## v1.0.0

First release on CurseForge.

- **Speak your race's language.** `/tongue <lang> <text>` (or `/lang`) says your line in Thalassian, Darnassian, Dwarvish, Gnomish, Orcish, Taur-ahe, Zandali, Gutterspeak, Demonic, Draconic or Titan. Anyone with EzTongues whose character knows it sees the translation after the line; everyone else hears the tongue.
- **Not a translator for the game's languages, and not cross-faction.** EzTongues doesn't translate the game's own racial languages and can't read the other faction's chat (the server garbles it before any addon sees it). It's a roleplay language between players of the same faction who both run it.
- **Any channel.** `y`, `p`, `g`, `o`, `r` and `e` after the language yell, party, guild, officer, raid or emote it (an emote's "quoted speech" only); `w <name>` whispers it (the first name of your target, someone you whispered with or someone in your group fills in their surname). `/tongue default <lang>` lets you skip the language.
- **Tagged like NPCs.** Lines start with their language, `[Orcish] Lok'tar ogar!`, so everyone sees what's spoken, addon or not. Off on the options page if you'd rather not.
- **Lore first.** Well-known phrases come out as the real thing: Lok'tar ogar, Shorel'aran, Elune-adore, Throm-ka, Belan shi.
- **Words you can learn.** Common words always come out the same, from Blizzard's own word lists, so regulars pick them up. Names and rare words are ciphered in the language's style.
- **Dialects.** A guild or group can speak a language its own way: everyone adds the same passphrase (`/tongue dialect add orcish Bloodfang <passphrase>`, or the Dialects page under Esc > Options > AddOns > EzTongues). Lines drift a few letters (`[Orcish dialect] Lon'rat ogat!`) and only those with the passphrase read them.
- **Honor system.** Each character knows its race's language, Orcish if Horde, Demonic if a warlock; learn or forget others with `/tongue learn|forget` or on the options page.
- **A box of your own.** A key binding (Options > Keybindings > EzTongues) or `/tongue box` opens an edit box with a language dropdown that works like the chat box: the channel shows at the start of the line, `/y`, `/p`, `/w bob `... switch it, Tab whispers the next person you talked with, Up brings back a line. A line too long for one message goes out one piece per Enter.
- **Whisper from EzAcquaintances.** Right-click its book's Whisper button and pick "In a tongue" to open the box already on a whisper to that person.
- `/tongue test [lang] <text>` shows a line in a language and back, sending nothing. `/tongue list` lists them.
