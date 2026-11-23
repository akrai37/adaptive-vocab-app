# Content

`words.json` is the word list (v2: English, 143 words in 12 groups, each with
a short fact for children).

## Word shape

```json
{ "id": "cat", "category": "animals", "emoji": "🐈", "image": "images/cat.png",
  "text": { "en": "cat" }, "fact": { "en": "A cat says meow." },
  "audio": { "en": null } }
```

- `id` never changes. The answer log refers to words by `id`, so it must stay
  stable when languages are added.
- `text` and `audio` are keyed by language. Adding Portuguese later means
  adding `"pt"` entries, not changing code.
- `image` is the picture file under `content/`. `emoji` is a fallback if the
  file is missing.
- `fact` is one short sentence shown on the card and read aloud after the
  word. Keep it under 60 characters and true.
- `audio: null` means use the device's text-to-speech until a recording exists.

## How words were picked

v2 (2026-11-10) grew the list for Prof. Figueira's feedback ("more
categories, more content"). Look-alike pictures in the same group were left
out on purpose (e.g. squid vs octopus, taxi vs car, banjo vs guitar), since
same-group choices are the "hard" questions.

- Concrete nouns that one picture can show without ambiguity.
- Short (mostly 3–5 letters), so they also work for the spelling game.
- Each category has look-alike or related words (apple / orange / grape,
  eye / ear / nose). Same-category distractors make a hard quiz, and
  cross-category distractors make an easy one.

## Sources

- **Images:** Google Noto Emoji, 512 px PNGs from
  https://github.com/googlefonts/noto-emoji (`2D/png/512`), Apache License 2.0.
  Bundled in `images/` so the app works offline.
- **Audio:** device text-to-speech for v1. Record a real voice later if needed.
