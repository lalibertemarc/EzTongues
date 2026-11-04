# EzTongues

Speak your race's language. Your line goes out as Thalassian, Orcish, Dwarvish... and anyone with EzTongues whose character knows that language sees what you said, in grey after the line. Everyone else hears the tongue. A WoW Forever and Classic Era addon for roleplayers.

> /tongue orcish Well met, friend. Have you seen Thrall?
>
> **Everyone sees:** [Orcish] Throm-ka, kanoka. Re'ka kek re'va Grak'Kztomm?
> **Who knows Orcish also sees:** [Orcish] Throm-ka, kanoka. Re'ka kek re'va Grak'Kztomm? *(Well met, friend. Have you seen Thrall?)*

The `[Orcish]` tag is how NPCs' lines in a language look; switch it off on the options page ("Name the language in your lines") and those who don't know the language see *(Orcish)* after the line instead, if they run EzTongues.

Languages: Thalassian, Darnassian, Dwarvish, Gnomish, Orcish, Taur-ahe, Zandali, Gutterspeak, Demonic, Draconic and Titan.

> **Not a cross-faction translator.** EzTongues has nothing to do with the game's own language garbling. When the other faction talks, the server swaps each of their words for a random one from a word list and the original is gone, so no addon can read it back. EzTongues lines are ordinary chat between players of the **same faction** who both run the addon; the other faction sees the server's gibberish on top of ours, with no translation. EzTongues borrows Blizzard's word lists so its languages look right, which means a short garbled line from the other faction can now and then look like an EzTongues line and get a nonsense "translation". Ignore it.

## Commands

| Command | Does |
|---|---|
| `/tongue <lang> <text>` | Say it in that language (`/lang` and `/eztongues` work too). `lang` is a name or a short one: `tha`, `darn`, `dwarf`, `gnome`, `orc`, `tauren`, `troll`, `forsaken`, `demon`, `dragon`, `titan` |
| `/tongue <lang> y\|p\|g\|o\|r\|e <text>` | Yell, party, guild, officer, raid or emote it (in an emote with "quoted speech", only the quotes are in the language); `/tongue <lang> s <text>` says a line starting with one of those letters |
| `/tongue <lang> w <name> <text>` | Whisper it: `"First Surname"`, `%t`, or just the first name of your target, someone you whispered with lately or someone in your group (their surname is filled in) |
| `/tongue <text>` | Your default language; `/tongue default <lang>` sets it |
| `/tongue test [lang] <text>` | Print it in the language and back, send nothing |
| `/tongue list` | Every language, and which you know |
| `/tongue learn\|forget <lang\|all>` | What this character speaks |
| `/tongue dialect` | Your dialects, and the commands below |
| `/tongue dialect add <lang> <Name> <passphrase>` | Add your guild's dialect of a language, and speak it from then on |
| `/tongue dialect use <name>` | Speak its language in that dialect |
| `/tongue dialect plain <lang\|all>` | Speak plain again (you still read your dialects) |
| `/tongue dialect forget <name>` | Neither speak nor read it any more |
| `/tongue box` | The edit box |
| `/tongue config` | The options page (Options > AddOns > EzTongues) |

**The box.** Bind a key under Options > Keybindings > EzTongues (or `/tongue box`). Type, press Enter to say it. The dropdown on the left picks the language (ones you don't know are greyed). The channel shows at the start of the line, as in chat (`Say:`, `Tell Jaina Proudmoore:`), and the box stays on it. To switch, start a line the way chat does: `/y`, `/p`, `/g`, `/o`, `/r`, `/e` or `/w name` and a space. `/w jaina ` fills in the surname of someone the box knows: your target, the people you whispered with (either way, the last 10 per character) and your group. A first name it doesn't know waits for its surname (`/w Bob Smith `), since Forever whispers need both; `/w "First Surname" ` works too. Tab whispers the next of those people, and clicking the channel lists every channel and person. Up/Down bring back earlier lines with their channel; Escape closes. Click anywhere else and it lets go of the keyboard so you can walk, but stays open.

**Knowing a language is the honor system.** A new character knows its race's language (Forsaken: Gutterspeak), Orcish if it's Horde and Demonic if it's a warlock. Alliance common is just Common, what you type. Learn or forget the rest on the options page or with `/tongue learn`. Anyone with EzTongues *could* read every language; what your character understands is up to you. Your own lines always show their translation.

In an emote, the tag goes right before each "quote": `smiles. [Orcish] "Throm-ka!"`. Long lines carry it on every piece.

Chat links, raid marks like `{skull}`, numbers and punctuation come through untouched, capitals are kept (Capitalized, ALL CAPS), `%t` becomes your target's name before the line is turned into the language, and long lines are split at the 255-character chat limit.

## Dialects

A guild or group can have its own way of speaking a language, without a new language. Everyone adds the same passphrase to the same language, under any name they like:

> /tongue dialect add orcish Bloodfang wolves of the north

The passphrase picks a few letter swaps (consonant for consonant, vowel for vowel) laid over the whole line, lore phrases too. It still sounds like Orcish, only drifted:

> **Plain Orcish:** [Orcish] Lok'tar ogar, Grak'Kztomm!
> **Bloodfang:** [Orcish dialect] Lon'rat ogat, Gtan'Nbromm! *(Victory or death, Thrall!)*

Only those with the passphrase read it. Everyone else sees `[Orcish dialect]` and no translation, even if they know Orcish. Dialect lines always carry that tag, even with tags switched off on the options page, since it's what tells them apart from plain lines. A passphrase's capitals and spacing don't matter, its words do: pick one that isn't easy to guess. It isn't encryption, though: anyone given the passphrase reads it.

Leave whenever you like. `/tongue dialect plain orcish` speaks plain again and keeps reading the dialect; `/tongue dialect forget Bloodfang` stops reading it too. To move to a new dialect, add the new one and keep the old one a while to read those who haven't moved yet. Nothing is stored anywhere but your own saved variables. A passphrase gives the same dialect forever, so old lines keep reading. The box's language dropdown lists your dialects under their language.

Two dialects of the same language rarely clash, but a very short line (a word or two) can now and then read as something else in the other one.

## How it works

No addon messages and no server: the line itself carries its meaning, so it works wherever chat does, and an alt can read lines from before it was made. Each word goes through, in order:

1. **Lore phrases.** A short table per language from Warcraft Wiki: "victory or death" is *Lok'tar ogar*, "farewell" is *Shorel'aran*, "Elune be with you" is *Elune-adore*, "thank you" in Draconic is *Belan shi*. Typed in plain chat on their own, these are recognised too.
2. **A dictionary.** The 1,650 most common English words, each paired with one word from Blizzard's own word list for that language (the words the game garbles chat into) or a word built from its syllables, as close to the same length as it can be so the line keeps its rhythm. Pairs never change, so regulars can learn them: in Orcish, *ogg* is "the".
3. **A letter cipher** for everything else (names, rare words, typos): consonants swap with consonants and vowels with vowels, plus each language's flavor (Thalassian doubles a vowel, Orcish a final k or g), behind a marker like *Grak'* or *Lae'*: Thrall is *Grak'Kztomm* in Orcish and *Lae'Lsheett* in Thalassian.

Plain English is never taken for a language: dictionary words are never common English words, and a line counts only when every word in it is that language's.

## For developers

- `Dictionary.lua` is generated by `tools/build_dictionary.py` (Python 3, `lua` on PATH). It downloads Blizzard's `LanguageWords`/`Languages` tables for WoW Forever from wago.tools and SymSpell's English frequency list once into `tools/cache/`. **It is append-only:** existing pairs never move, new English words only get native words nobody has; the tool refuses to run rather than reshuffle. `--check` exits 1 if the file would change.
- `Data.lua`'s ciphers, markers and phrases are frozen the same way: add, never edit. So is `Dialect.lua`'s drift (passphrase normalizing, hash, generator, letter pools, pair counts): a passphrase must give the same swaps forever. `tests/pinned.lua` pins dialect samples too.
- `lua tests/smoke.lua` (Lua 5.1, WoW API stubbed) round-trips a few hundred lines in every language, checks plain English stays plain, checks the dictionary's rules, pins sample encodings (`tests/pinned.lua`) and runs the slash command and chat filter end to end. CI runs it with luacheck.
