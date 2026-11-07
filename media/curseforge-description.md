# EzTongues

*Speak your race's language. Those who know it understand you.*

Your blood elf greets an old friend in Thalassian. Your orc barks orders in Orcish. Everyone around you hears the tongue, and anyone running EzTongues whose character knows that language also sees what you said, in grey after the line.

> /tongue orcish Well met, friend. Have you seen Thrall?
>
> **Everyone sees:** [Orcish] Throm-ka, kanoka. Re'ka kek re'va Grak'Kztomm?
>
> **Those who speak Orcish also see:** *(Well met, friend. Have you seen Thrall?)*

**Thalassian, Darnassian, Dwarvish, Gnomish, Orcish, Taur-ahe, Zandali, Gutterspeak, Demonic, Draconic and Titan.**

> **Not a translator for the game's languages, and not cross-faction.** EzTongues doesn't translate the game's own racial languages, and it can't read the other faction's chat. It's a roleplay language between players of the same faction who both run it. More below.

The `[Orcish]` tag is how NPCs speak a language in the game, so even players without the addon know what they're hearing. Rather go without it? Switch it off on the options page.

## Important: not a translator for the game's languages, not cross-faction

EzTongues **does not translate the game's own languages**, and it **cannot** read what the other faction says. It doesn't try to.

- **The game's languages are separate.** Picking Orcish or Thalassian in the chat box's language menu is the game's own feature, and EzTongues has nothing to do with it. It doesn't translate those lines, and its own languages don't unlock or replace them.
- **The other faction stays garbled.** When a Horde player talks near an Alliance player (or the other way around), the game server replaces every word with a random word from Blizzard's language lists before it reaches you. The original words are thrown away, so no addon can ever turn that back into English.

EzTongues is something else: roleplay languages for players of the **same faction**. Your line goes out as ordinary chat already written in the language, and the addon on your friends' side reads it back. If someone of the other faction hears an EzTongues line, the server garbles it like any other line and they see no translation.

EzTongues uses Blizzard's word lists so its languages look like the real thing. Because of that, a short garbled line from the other faction can sometimes look like an EzTongues line and get a "translation" that makes no sense. That's not what they said: just ignore it.

## Speaking

- `/tongue <language> <text>` says it (`/lang` works too). Short names are fine: `orc`, `tha`, `darn`, `dwarf`, `gnome`, `tauren`, `troll`, `forsaken`, `demon`, `dragon`, `titan`.
- `/tongue <language> y|p|g|o|r|e <text>` yells, or sends it to party, guild, officer, raid or emote. In an emote, only the "quoted speech" is in the language.
- `/tongue <language> w <name> <text>` whispers it. Your target's first name is enough, or the first name of someone you whispered with or someone in your group.
- `/tongue default <language>` sets your default, then just `/tongue <text>`.
- `/tongue test <text>` shows you your line in the language and back, without sending anything.

Item links, raid marks like {skull}, numbers and punctuation come through untouched, capitals are kept, and `%t` becomes your target's name.

**Long lines.** The game lets an addon send one message per key press in say, yell and emotes, so a line too long for one message goes out a piece at a time: the box opens with the rest waiting, press Enter for each.

## The tongue box

Bind a key (Options > Keybindings > EzTongues) or type `/tongue box` for an edit box of your own, with a language dropdown. Type, press Enter.

It works like the chat box: the channel shows at the start of the line (`Say:`, `Tell Jaina Proudmoore:`) and stays put. Type `/y`, `/p`, `/e`... and a space to switch, or `/w jaina ` to whisper (her surname is filled in when the box knows her). Tab cycles through the people you've whispered with, and Up brings back an earlier line with its channel.

## Knowing a language

Each character starts out knowing their race's language (Forsaken: Gutterspeak), Orcish if they're Horde, and Demonic if they're a warlock. Learn or forget others on the options page or with `/tongue learn <language>`.

**It's the honor system.** Anyone with EzTongues could read every language if they ticked the boxes. What your character understands is up to you and your roleplay.

## Dialects: a language only your guild reads

A guild or group can speak a language its own way. Everyone adds the same passphrase to the same language, under any name they like:

> /tongue dialect add orcish Bloodfang wolves of the north

Your lines still sound like Orcish, just drifted a few letters:

> **Plain Orcish:** [Orcish] Lok'tar ogar, Grak'Kztomm!
>
> **Bloodfang:** [Orcish dialect] Lon'rat ogat, Gtan'Nbromm! *(Victory or death, Thrall!)*

Only those with the passphrase read it. Everyone else sees `[Orcish dialect]` and no translation, even if they know Orcish. Switch back to plain Orcish any time and keep reading the dialect.

Prefer clicking? Esc > Options > AddOns > EzTongues > **Dialects** lists every dialect you know, with buttons to speak it, speak plain or forget it, and a box to add a new one.

## Lore and words you can learn

Well-known lines come out as the real thing: *Lok'tar ogar*, *Shorel'aran*, *Elune-adore*, *Throm-ka*, *Belan shi*. Common words always come out the same way, so regulars start picking them up (in Orcish, *ogg* is "the"). Names and rare words are spelled out in the language's style: Thrall is *Grak'Kztomm* in Orcish and *Lae'Lsheett* in Thalassian.

The words never change between versions, so a line said today will still translate after every update.

## Options

Esc > Options > AddOns > EzTongues: the languages you know, your default language, a preview, the box, the language tag, the color of translations, and whether to show the name of languages you don't know.

For WoW Forever and Classic Era. No addon messages, no setup: the line itself carries its meaning, so it works wherever chat does.

## Better with friends: the EzAddons family

EzTongues is one of a set of roleplay addons that work hand in hand:

- **EzAccent**: type normally, speak in your race's accent. One for Common, the other for your own tongue.
- **EzOOC**: out-of-character lines in `(( ))`, with the same kind of box.
- **EzAcquaintances**: a contact book of the people you've met. Right-click its Whisper button and pick "In a tongue" to open the EzTongues box already on a whisper to them.
- **EzEmote**: an emote palette and wheels for everything your character does while they talk.

Every one of them is free and stands on its own.

## Join us on Discord

Come say hi: **[join the EzAddons Discord](https://discord.com/invite/bZrAYqbsD8)**.

- Hear about new versions first (pick the addons you care about and get pinged when they update).
- Suggest a lore phrase your language is missing, or a word that comes out wrong.
- Report bugs, and help test what's coming next.

## Tell us what you think!

A phrase your orc would say that the addon doesn't know? A language you'd like to see? **Drop it in the [Discord](https://discord.com/invite/bZrAYqbsD8), leave a comment, or open an issue on [GitHub](https://github.com/lalibertemarc/EzTongues/issues)** and it might be in the next update.
