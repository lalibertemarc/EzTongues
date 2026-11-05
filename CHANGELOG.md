# EzTongues

## v1.0.0-beta.2

- **Much lighter.** Uses about 2 MB less memory once chat is heard: words are looked up in the dictionary as needed instead of being copied into big tables for every language.

## v1.0.0-beta.1

- **Whisper from EzAcquaintances.** Its book's Whisper button can open this box already on a whisper to that person (right-click the button and pick "In a tongue").
- **Long lines no longer get stuck.** The game lets an addon say only one message per key press in say, yell, emotes and channels, so the second piece of a line too long for one message was blocked ("tried to call the protected function"). Now the first piece goes out and the box opens with the rest waiting: press Enter for each (or `/tongue more`), Escape drops them. Party, raid, guild, officer and whispers still get every piece at once.
- **Speak your race's language.** `/tongue <lang> <text>` (or `/lang`) says your line in Thalassian, Darnassian, Dwarvish, Gnomish, Orcish, Taur-ahe, Zandali, Gutterspeak, Demonic, Draconic or Titan. Anyone with EzTongues whose character knows it sees the translation after the line; everyone else hears the tongue (and, if they like, its name).
- **Any channel.** `y`, `p`, `g`, `o`, `r` and `e` after the language yell, party, guild, officer, raid or emote it (an emote's "quoted speech" only); `w <name>` whispers it (the first name of your target, someone you whispered with or someone in your group fills in their surname). `/tongue default <lang>` lets you skip the language.
- **Tagged like NPCs.** Lines start with their language, `[Orcish] Lok'tar ogar!`, so everyone sees what's spoken, addon or not (in an emote, before each "quote"). Off on the options page if you'd rather not.
- **Dialects.** A guild or group can speak a language its own way: `/tongue dialect add orcish Bloodfang <passphrase>`. The passphrase drifts a few letters of every line (`[Orcish dialect] Lon'rat ogat!`), and only those who added the same passphrase read it. `/tongue dialect use|plain|forget` switch between dialects, back to plain or leave one; the box's dropdown lists them under their language.
- **Lore first.** Well-known phrases come out as the real thing: Lok'tar ogar, Shorel'aran, Elune-adore, Throm-ka, Belan shi.
- **Words you can learn.** Common words always come out the same, from Blizzard's own word lists, so regulars pick them up. Names and rare words are ciphered in the language's style.
- **Honor system.** Each character knows its race's language, Orcish if Horde, Demonic if a warlock; learn or forget others with `/tongue learn|forget` or on the options page.
- **A box of your own.** A key binding (Options > Keybindings > EzTongues) or `/tongue box` opens an edit box with a language dropdown. Enter says the line, Escape closes it. The channel shows at the start of the line, as in chat (`Say:`, `Tell Jaina Proudmoore:`), and the box stays on it: type `/y`, `/p`, `/e`... and a space to switch, or `/w bob ` to whisper (his surname filled in when the box knows him: your target, the people you whispered with, your group). Tab whispers the next of those people, a click on the channel lists them all with the channels, and Up brings back a line with its channel.
- **An options page.** Esc > Options > AddOns > EzTongues: languages you know, default language, a preview, the box, the translation's color, and whether to name languages you don't know.
- `/tongue test [lang] <text>` shows a line in a language and back, sending nothing. `/tongue list` lists them.
