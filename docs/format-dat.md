# Formát dat scén

Každá scéna je jeden soubor `data/scenes/<id>.json` a jeden obrázek pozadí. Nová scéna nepotřebuje žádný kód: stačí ji přidat do `data/game.json` → `scenes`, doplnit texty do `locale/texts.csv` a pustit testy.

Souřadnice jsou v pixelech obrázku 1920×1080, levý horní roh je `[0, 0]`. Spodních 150 px zabírá inventář, proto `walk_area` končí nejníž na y = 900.

## Scéna

| Klíč | Co to je |
| --- | --- |
| `title` | Textový klíč názvu scény (ukazuje se na placeholderu). |
| `background` | Cesta k obrázku pozadí, např. `res://art/scenes/c1_stable.png`. Dokud neexistuje, kreslí se placeholder. |
| `foreground` | Volitelná vrstva popředí, za kterou Lili zajde (PNG s průhledností). |
| `placeholder_color` | Barva placeholderu, dokud není obrázek. |
| `walk_area` | Polygon, po kterém Lili chodí. Může být nekonvexní, Lili obejde rohy. |
| `depth_scale` | `[y_daleko, y_blízko, měřítko_daleko, měřítko_blízko]`: Lili se nahoře zmenšuje. |
| `lili_start` | Kde Lili stojí, když do scény přijde poprvé. |
| `entries` | Kde Lili stojí podle scény, ze které přišla: `{"c1_yard": [160, 820]}`. |
| `on_enter` | Akce při vstupu do scény (typicky úvodní cutscéna přes `once`). |
| `cutscenes` | Pojmenované seznamy akcí. |
| `hotspots` | Interaktivní místa (níže). |
| `dialogues` | Rozhovory (níže). |
| `hints` | Šerifovy rady (níže). |

## Hotspot

```json
{
  "id": "hay",
  "name": "HS_HAY",
  "if": "!got_horseshoe",
  "polygon": [[1250, 420], [1700, 420], [1760, 700], [1200, 700]],
  "walk_to": [1300, 780],
  "interact": [ ... akce ... ],
  "look": [ ... akce, použije se, když chybí interact ... ],
  "use": { "pitchfork": [ ... akce ... ], "*": "SAY_NOPE" },
  "exit": "c1_yard", "exit_if": "joe_told", "blocked": "SAY_NOT_YET"
}
```

- `if`: hotspot je vidět, jen když podmínka platí (např. sebraný předmět zmizí).
- `walk_to`: kam Lili dojde, než akci provede. Musí ležet ve `walk_area`.
- `use`: co se stane, když na hotspot hráč přetáhne předmět. `"*"` platí pro všechny ostatní předměty.
- `exit`: ťuknutí přenese Lili do jiné scény. S `exit_if` jen pokud podmínka platí, jinak zazní `blocked`.

## Akce

Kde se čeká seznam akcí, stačí i jeden textový klíč: `"SAY_HAY_EMPTY"` znamená, že to řekne Lili.

| Akce | Co dělá |
| --- | --- |
| `{"say": "KLÍČ", "who": "joe"}` | Postava něco řekne (`who` výchozí `lili`, `narrator` je vypravěč bez jména a hlasu). |
| `{"give": "item"}` / `{"take": "item"}` | Přidá nebo odebere předmět. |
| `{"set": "flag"}` / `{"clear": "flag"}` | Nastaví nebo smaže příznak. |
| `{"if": "podmínka", "then": [...], "else": [...]}` | Větvení. |
| `{"once": "flag", "do": [...], "else": [...]}` | Provede `do` jen poprvé, pak `else`. |
| `{"goto": "scena"}` | Přechod do jiné scény. |
| `{"dialogue": "id"}` | Spustí rozhovor. |
| `{"cutscene": "id"}` | Spustí cutscénu (černé pruhy, skrytý inventář). |
| `{"walk": [x, y]}` | Lili dojde na místo. |
| `{"wait": 1.5}` | Pauza v sekundách. |
| `{"fade": 1}` / `{"fade": 0}` | Zatmívačka do černé a zpět. |
| `{"image": "res://art/cutscenes/x.png", "color": "#f3b562", "caption": "KLÍČ"}` | Obrázek přes celou obrazovku (cutscény). |
| `{"image_clear": true}` | Skryje obrázek. |

## Podmínky

Řetězec s termy spojenými `&`: `"has:bucket & !fire_out"`.

- `flag`: příznak je nastavený. `!flag`: není.
- `has:item`: Lili má předmět v inventáři.
- `true` / `false`.

## Rozhovor

```json
"joe": {
  "start": "hi",
  "nodes": {
    "hi": {"who": "joe", "text": "DLG_JOE_HI", "options": [
      {"text": "DLG_JOE_OPT_HROM", "if": "!joe_told", "next": "hrom"},
      {"text": "DLG_JOE_OPT_BYE", "next": ""}
    ]},
    "hrom": {"who": "joe", "text": "DLG_JOE_HROM", "do": [{"give": "whistle"}], "next": "hi"}
  }
}
```

Uzel bez `options` pokračuje na `next`, prázdné `next` rozhovor ukončí. Volbu Lili nahlas zopakuje. Akce `do` se provedou při každém vstupu do uzlu, jednorázové věci proto obalte do `once`.

## Rady

```json
"hints": [
  {"id": "hay", "if": "!got_horseshoe", "keys": ["HINT_HAY_1", "HINT_HAY_2", "HINT_HAY_3"]}
]
```

Použije se první skupina, jejíž podmínka platí. Každé stisknutí tlačítka Rada jde o úroveň hlouběji, poslední rada má říct přesný postup.

## Předměty a kombinace

`data/items.json`: `items` mají `name`, `look`, `color` (barva placeholderu) a `icon`. `combos` říkají, co vznikne spojením dvou předmětů v inventáři (pořadí nehraje roli).

## Texty

`locale/texts.csv`, první sloupec klíč, další sloupce jazyky (`cs`, později `en`…). Do obrázků se žádný text nekreslí.

## Testy

Návod hry krok po kroku patří do `tests/walkthroughs/*.json`. Test ho přehraje bez grafiky a selže, pokud nějaký krok nejde provést. Kromě toho kontroluje, že všechny texty, předměty, scény, rozhovory a body ve `walk_area` existují a dávají smysl.
