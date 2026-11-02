"""Writes EzTongues' Dictionary.lua: the most common English words, each paired one-to-one with a native word in
every language of Data.lua's ns.TONGUES.

Sources (downloaded once into tools/cache/, which git ignores; --refresh fetches them again):
  * Blizzard's per-language word lists, LanguageWords.db2 (with Languages.db2 for the names), as CSV from
    wago.tools for the WoW Forever build in BUILD. These are the words the game itself garbles chat into.
  * English word frequencies: SymSpell's frequency_dictionary_en_82_765.txt (github.com/wolfgarbe/SymSpell, MIT),
    built from Google Books Ngram counts (CC BY 3.0) intersected with SCOWL. Only the word order is used.

Pairing: English words in frequency order (then EXTRAS) each get an unused native word of the same length,
Blizzard's own words first (so the most common English words get them), then words built from that language's
syllables. A native word is never an English word, never taken by another language, never a word of a lore phrase,
and never starts with a cipher marker plus an apostrophe, so the addon can always tell which language and which path
(dictionary, phrase, cipher) a word came from.

APPEND-ONLY. Lines already sent must keep decoding, and players learn words, so a pair never changes once it is in
Dictionary.lua. Each run reads the committed file, keeps every pair as it is, and only appends pairs for English
words that are new (native words that are still free). It refuses to run if the file breaks a rule (say a new lore
phrase uses a word that's already paired) instead of reshuffling.

Usage (from the EzTongues folder, needs `lua` on PATH to read Data.lua):
  python tools/build_dictionary.py           update Dictionary.lua (appends only)
  python tools/build_dictionary.py --check   exit 1 if the file is invalid or would change; writes nothing
  python tools/build_dictionary.py --refresh download the sources again first
"""

import argparse
import csv
import random
import re
import subprocess
import sys
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache"
OUT = ROOT / "Dictionary.lua"
DATA = ROOT / "Data.lua"

BUILD = "1.60.1.70707"  # WoW Forever (wago.tools product "wowf")
WAGO = "https://wago.tools/db2/{table}/csv?build=" + BUILD
FREQ_URL = ("https://raw.githubusercontent.com/wolfgarbe/SymSpell/master/SymSpell/"
            "frequency_dictionary_en_82_765.txt")

N_ENGLISH = 1500      # most common words from the frequency list
ENGLISH_GUARD = 20000  # native words may not be any of this many most common English words
SYNTH_TRIES = 60000   # words built per language from its syllables

WORD = re.compile(r"^[a-z]+(?:'[a-z]+)*$")  # the addon's word grammar (Codec.lua), lower case

# The frequency list is web text: these (web, shopping, tech, modern places and names, months, smut) would take
# Blizzard's best words from words that are said in character. Skipped words still get ciphered.
SKIP = set("""www com http https html htm org net pdf php xml url urls jpg gif faq isbn dvd dvds cd cds tv pc pcs
mp mp3 inc ltd llc pp vs etc st nd rd th de la le el du des der und di da en uk usa eu ca ny dc fl tx nc pa va
ii iii iv vi vii viii ix xi xp rss api sql css js ip tcp ie gb mb kb mg ml cm km mm kg lb lbs oz ft sq jan feb
apr jun jul aug sep sept oct nov dec tue thu fri pm re id co al los san est eur int prev max mini multi non pro
page pages search info information site sites web website online click contact email mail news business service
services price prices date product products system systems policy policies copyright support message messages
software video videos rights privacy item items user users review reviews program programs programme games hotel
hotels ebay store stores comments comment development report reports details terms results office education
national car cars design posted internet address phone shipping reserved subject forum forums code index file
files link links technology technologies sports security county photo photos photography network networks
computer computers download downloads access resources resource posts media pictures pics guide guides shop
shopping directory location locations text rating ratings rate rates government students student account profile
previous form forms events department title description insurance property properties listing listings content
visit tools reply customer customers compare movies movie college article articles card cards jobs job provide
provides providing source sources author authors press sale sales print course courses process teen teens stock
training credit categories category advanced estate conditions select windows gay thread gallery table register
registered registration market library series model models features featured industry industrial provided
required accessories cost costs questions yahoo medical test testing server application applications cart staff
feedback issues issue topic topics financial finance working standard standards tax mobile blog payment equipment
login programs offers offer legal recent performance social quote options option experience create activities
club example additional password latest status browse range building seller sellers texas poker audio groups
release releases released analysis request fax china picture professional areas committee problems london
washington meeting interest enter california porn share schools reference companies company listed learning
energy delivery popular film journal images image president notice radio cell council includes track australia
discussion archive archives entertainment agreement format society log safety trade edition marketing updated
update association david collection display limited powered solutions solution director daily electronics
electronic planning database official technical window france region record records direct microsoft conference
environment environmental district calendar statement parts documents document material materials bill federal
hosting rules adult tickets centre center requirements via cheap nude kids percent function functions unit global
tech projects project lyrics subscribe submit germany amount included bank deals linux production commercial
james advertising advertise newsletter magazine error camera cameras currently construction toys golf domain
methods method chapter protection loan loans manager india position michael engineering florida wireless license
paul friday monday tuesday wednesday thursday saturday sunday january february march april june july august
september october november december annual published sony corporate corporation google purchase hardware holiday
chat designed countries brand brands discount effects political storage japan japanese shoes entry orders
availability africa summary agency european europe activity drug western income cash employment overall
commission package contents players engine port album regional supplies administration institute views exchange
types sponsored benefits printer organization organizations selection casino tour menu volume mortgage mature
executive clothing robert homepage gas skills bush advice career rental british facilities zip bid cable
opportunities opportunity division lesbian appropriate machine logo statistics client returns investment christmas
england flash george thomas consumer airport artist artists furniture channel mode phones structure fund funds
degree contract button male virginia located multiple asian distribution editor communications communication
associated cancer browser foundation schedule independent physical operating operations operation maps medicine
chicago smith developed develop development survey telephone mexico population navigation ass christian paypal
publications publication publisher worldwide connection nokia transfer introduction carolina hospital overview
accommodation owners owner italy kit classic william express anal award assessment interface pussy partners
partner budget rated maximum existing selected amazon patients restaurants retail manufacturer housing searches
traffic input strategy agent valid bin senior ireland sexy enterprise educational fitness chinese abstract output
employees alternative processing resolution java relations van session republic fees components vacation academic
assistance graphics indian ads mary dating pacific pop filter mailing vehicle panel proposed default iraq outdoor
protein transportation politics disclaimer boards faculty membership modified pack internal recommended richard
detailed approved background target maintenance trademarks sex canada york john english america american
united university states state international management health data online shipping insurance hotels
microsoft rape incest xxx milf cum hardcore naked breast oral ringtones keywords galleries blogs username classifieds
paperback upgrade desktop programming installation module pricing documentation automotive commerce satellite accounting apparel servers websites rentals
tel networking updates monitoring sec install boston ohio jersey paris georgia michigan columbia angeles francisco colorado
vegas illinois zealand kansas arizona israel spain asia canadian german spanish russian australian italian peter martin
mike tom chris lee charles bob steve scott johnson jones jim ford canon mac santa""".split())

# Said a lot in character, but rare in books or missing from the frequency list (it has no contractions).
EXTRAS = """i'm i've i'll i'd you're you've you'll you'd he's she's it's we're we've we'll they're they've they'll
that's there's here's what's who's where's how's let's don't doesn't didn't can't couldn't won't wouldn't
shouldn't isn't aren't wasn't weren't haven't hasn't hadn't ain't y'all o'clock
hi hey hello yes yeah yep nope okay ok thanks thank please sorry bye goodbye greetings farewell welcome aye nay
mon lad lass ma'am sir madam lol hmm huh oh ah ha haha
horde alliance light shadow shadows elf elves orc orcs troll trolls dwarf dwarves gnome gnomes tauren undead
forsaken human humans dragon dragons demon demons titan titans magic mage mages priest paladin warrior rogue
hunter shaman druid warlock sword swords axe shield bow arrow arrows staff armor potion gold silver copper ale
beer mead wine tavern inn king queen prince princess lord lady brother sister friend friends enemy enemies honor
glory blood death victory battle war peace sun moon star stars earth fire water wind spirit spirits soul souls
ancestors elune loa beast beasts wolf bear boar raptor kodo spider forest mountain river sea village city castle
tower temple quest journey traveler stranger""".split()


# Blizzard words that are also well-known lore names or words: typed on their own in plain chat they'd be
# "translated" into something else, so they stay out of the dictionary.
LORE = set("""al'ar dorei sin'dorei quel'dorei kaldorei kal'dorei shu'halo lok tar dabu aka'magosh throm loa
elune azeroth draenor thrall""".split())


def fetch(url, path, refresh):
    if refresh or not path.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        print(f"downloading {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "EzTongues build_dictionary.py"})
        with urllib.request.urlopen(req, timeout=60) as r:
            path.write_bytes(r.read())
    return path


def load_data():
    """Data.lua via Lua itself: languages in order with id and markers, and their phrases."""
    out = subprocess.run(["lua", str(ROOT / "tools" / "dump_data.lua"), str(DATA)],
                         capture_output=True, text=True, encoding="utf-8", check=True).stdout
    langs, phrases = [], defaultdict(list)
    for line in out.splitlines():
        f = line.split("\t")
        if f[0] == "L":
            langs.append({"key": f[1], "id": f[2], "markers": f[3].split(",")})
        elif f[0] == "P":
            phrases[f[1]].append((f[2], f[3]))
    return langs, phrases


def tokens(text):
    """Words of a line by the addon's grammar: letters, with single apostrophes inside."""
    return [m.group(0).lower() for m in re.finditer(r"[A-Za-z]+(?:'[A-Za-z]+)*", text)]


def english_words(freq_path):
    ranked = []
    for line in freq_path.read_text(encoding="utf-8-sig").splitlines():
        w = line.split(" ")[0].strip().lower()
        if w and re.fullmatch(r"[a-z]+", w):
            ranked.append(w)
    guard = set(ranked[:ENGLISH_GUARD])
    words = []
    for w in ranked:
        if len(words) >= N_ENGLISH:
            break
        if w in SKIP or (len(w) == 1 and w not in ("a", "i")):
            continue
        words.append(w)
    seen = set(words)
    for w in EXTRAS:
        assert WORD.match(w), w
        if w not in seen:
            words.append(w)
            seen.add(w)
    return words, guard | seen


def blizzard_words(words_csv, lang_id):
    out = []
    with open(words_csv, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["LanguageID"] == lang_id:
                out.append(row["Word"].strip().lower())
    return out


def letters(w):
    return len(w.replace("'", ""))


SYL = re.compile(r"[^aeiouy]*[aeiouy]+(?:[^aeiouy]*$|[^aeiouy](?=[^aeiouy]))?")


def synthesize(key, source):
    """Words built from a language's own syllables: first + middles + last, an apostrophe as often as its words
    have one."""
    first, middle, last, single = [], [], [], []
    counts, apostrophes, total = Counter(), 0, 0
    for w in source:
        if not WORD.match(w):
            continue
        total += 1
        apostrophes += "'" in w
        syl = []
        for seg in w.split("'"):
            parts = SYL.findall(seg)
            if "".join(parts) != seg:
                parts = []
            syl += parts
        if not syl:
            continue
        counts[len(syl)] += 1
        if len(syl) == 1:
            single.append(syl[0])
        else:
            first.append(syl[0])
            last.append(syl[-1])
            middle += syl[1:-1]
    middle = middle or first + last
    single = single or first
    p_apos = apostrophes / total if total else 0
    sizes, weights = zip(*sorted(counts.items()))
    rng = random.Random("EzTongues synth " + key)
    built = set()
    for _ in range(SYNTH_TRIES):
        n = rng.choices(sizes, weights)[0] + rng.choice((0, 0, 1))
        if n == 1:
            parts = [rng.choice(single)]
        else:
            parts = [rng.choice(first)] + [rng.choice(middle) for _ in range(n - 2)] + [rng.choice(last)]
        w = re.sub(r"(.)\1\1+", r"\1\1", "".join(parts))  # no triple letters
        # One apostrophe at most, between two syllables of two letters or more: Dor'ano, not I'e.
        cuts = [i for i in range(1, len(parts))
                if len("".join(parts[:i])) >= 2 and len("".join(parts[i:])) >= 2 and len(parts[i]) >= 2]
        if cuts and rng.random() < p_apos:
            at = rng.choice(cuts)
            w = re.sub(r"(.)\1\1+", r"\1\1", "".join(parts[:at])) + "'" + \
                re.sub(r"(.)\1\1+", r"\1\1", "".join(parts[at:]))
        if WORD.match(w) and re.search(r"[^aeiouy']", w) and not re.search(r"[aeiouy]{3}", w):
            built.add(w)
    return sorted(built)


def read_dictionary():
    """{key: [(english, native), ...]} from the committed Dictionary.lua, in file order."""
    pairs = {}
    if not OUT.exists():
        return pairs
    text = OUT.read_text(encoding="utf-8")
    for key, body in re.findall(r"ns\.DICTIONARY\.(\w+) = \[\[\n(.*?)\]\]", text, re.S):
        pairs[key] = [tuple(line.split(" ")) for line in body.splitlines() if line.strip()]
    return pairs


def fail(msg):
    sys.exit("build_dictionary: " + msg + "\nDictionary.lua is append-only: fix Data.lua instead of reshuffling.")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--refresh", action="store_true")
    args = ap.parse_args()

    words_csv = fetch(WAGO.format(table="LanguageWords"), CACHE / f"LanguageWords-{BUILD}.csv", args.refresh)
    fetch(WAGO.format(table="Languages"), CACHE / f"Languages-{BUILD}.csv", args.refresh)
    freq = fetch(FREQ_URL, CACHE / "frequency_dictionary_en_82_765.txt", args.refresh)

    langs, phrases = load_data()
    english, guard = english_words(freq)
    existing = read_dictionary()

    markers = {}
    for lang in langs:
        for m in lang["markers"]:
            if not re.fullmatch(r"[a-z]+", m):
                fail(f"{lang['key']} marker {m!r} must be lower-case letters")
            if m in markers:
                fail(f"marker {m!r} is used by {markers[m]} and {lang['key']}")
            markers[m] = lang["key"]
    phrase_words = {}
    for key, plist in phrases.items():
        for en, native in plist:
            for t in tokens(native):
                phrase_words.setdefault(t, key)
                if "'" in t and t.split("'")[0] in markers:
                    fail(f"{key} phrase word {t!r} starts like a cipher word ({t.split(chr(39))[0]}')")

    def clash(native):
        """Why native can't be a dictionary word, or None."""
        if not WORD.match(native) or letters(native) < 2:
            return "not a plain word of two letters or more"
        if native in LORE:
            return "a lore word (LORE)"
        if native in phrase_words:
            return f"part of a {phrase_words[native]} lore phrase"
        if native in markers or ("'" in native and native.split("'")[0] in markers):
            return f"a cipher marker ({markers.get(native.split(chr(39))[0], markers.get(native))})"
        return None

    # The committed pairs stay exactly as they are; check they still hold.
    taken = {}
    for key, plist in existing.items():
        seen = set()
        for en, native in plist:
            if en in seen:
                fail(f"{key}: {en!r} is paired twice")
            seen.add(en)
            why = clash(native)
            if why:
                fail(f"{key}: {native!r} (for {en!r}) is now {why}")
            if native in taken:
                fail(f"{native!r} is paired in both {taken[native]} and {key}")
            taken[native] = key

    result, added = {}, Counter()
    for lang in langs:
        key = lang["key"]
        pairs = list(existing.get(key, []))
        have = {en for en, _ in pairs}
        todo = [w for w in english if w not in have]
        if todo:
            raw = blizzard_words(words_csv, lang["id"])
            if not raw:
                fail(f"no LanguageWords for {key} (id {lang['id']}) in build {BUILD}")

            def free(w):
                return w not in taken and w not in guard and clash(w) is None

            blizz = defaultdict(list)
            for w in sorted(set(raw)):
                if free(w):
                    blizz[letters(w)].append(w)
            synth = defaultdict(list)
            for w in synthesize(key, raw):
                if free(w) and w not in blizz[letters(w)]:
                    synth[letters(w)].append(w)
            for en in todo:
                rng = random.Random(f"EzTongues pair {key} {en}")
                n = letters(en)
                pick = None
                for d in [0] + [s * k for k in range(1, 12) for s in (1, -1)]:
                    for pool in (blizz, synth):
                        cands = [w for w in pool.get(n + d, []) if w not in taken]
                        if cands:
                            pick = rng.choice(cands)
                            pool[n + d].remove(pick)
                            break
                    if pick:
                        break
                if not pick:
                    fail(f"{key}: ran out of native words for {en!r}")
                taken[pick] = key
                pairs.append((en, pick))
                added[key] += 1
        result[key] = pairs
    for key in existing:
        if key not in result:
            fail(f"Dictionary.lua has {key} but Data.lua doesn't: languages are never removed")

    lines = [
        "-- EzTongues dictionary: English word -> native word, one pair per line, per language.",
        "-- GENERATED by tools/build_dictionary.py (Blizzard's LanguageWords for WoW Forever " + BUILD + ",",
        "-- English order from SymSpell's frequency list). Don't edit by hand.",
        "-- APPEND-ONLY: pairs never change or go away once released, so old lines keep decoding; the tool only",
        "-- adds pairs at the end of a list.",
        "local _, ns = ...",
        "",
        "ns.DICTIONARY = {}",
    ]
    for lang in langs:
        lines.append("")
        lines.append(f"ns.DICTIONARY.{lang['key']} = [[")
        lines += [f"{en} {native}" for en, native in result[lang["key"]]]
        lines.append("]]")
    text = "\n".join(lines) + "\n"

    old = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
    if args.check:
        if text != old:
            sys.exit("build_dictionary --check: Dictionary.lua would change (" +
                     ", ".join(f"{k} +{n}" for k, n in added.items()) + ")")
        print("Dictionary.lua is up to date.")
        return
    if text == old:
        print("Dictionary.lua is up to date.")
        return
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.name} ({len(text.encode()) // 1024} KB): " +
          ", ".join(f"{k} +{added[k]}" for k in result))


if __name__ == "__main__":
    main()
