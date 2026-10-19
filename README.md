# Lili a hřebec Hrom

Kreslená point-and-click adventura pro Android v Godotu 4.5. Pro děti 8 až 11 let, 23 scén v 7 kapitolách. Hra je hratelná od začátku do konce (všech 23 scén). Grafika je zatím placeholder a závod ve scéně 22 je jednoduchá minihra (ťukáním se přeskakují ohrady). Podle [design dokumentu](https://claude.ai/code/artifact/d8c64046-ecab-4cda-881c-07e08a4c3348).

## Spuštění

1. Nainstalujte [Godot 4.5](https://godotengine.org/download) (standardní verze, ne .NET).
2. Otevřete složku projektu v Godotu a stiskněte F5.

Bez grafiky se scény kreslí jako placeholdery: barevná plocha s obrysy klikacích míst.

## Ovládání

- Ťuknutí na místo: Lili tam dojde. Ťuknutí na předmět nebo postavu: interakce.
- Ťuknutí na předmět v inventáři ho vybere (žlutý rámeček). Další ťuknutí na místo ve scéně ho tam použije, ťuknutí na jiný předmět je spojí. Ťuknutí na vybraný předmět ho popíše a výběr zruší, ťuknutí na prázdné místo výběr zruší.
- Předmět jde i přetáhnout z inventáře na místo nebo na jiný předmět.
- Podržení prstu na scéně: zvýrazní všechna klikací místa.
- Tlačítko Rada: šerif napoví, každým stisknutím víc.

## Testy

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

Kontrolují data všech scén a přehrají návody v `tests/walkthroughs/`. Rychlá zkouška celé hry bez okna: `godot --headless --path . -- --smoke`. S přepínačem `--scene=c2_lookout` začne zkouška v jiné scéně, což se hodí při ladění.

## Struktura

| Složka | Obsah |
| --- | --- |
| `core/` | Logika bez grafiky: stav hry, pravidla, načítání dat, kontrola dat, chůze, mumlání |
| `scenes/` | Hlavní scéna, místnost a Lili |
| `ui/` | Inventář, titulky, dialogy, nápověda, cutscény |
| `data/` | Scény, předměty a postavy v JSON |
| `locale/texts.csv` | Všechny texty, sloupec na jazyk |
| `art/` | Pozadí scén, ikony předmětů, obrázky cutscén |
| `tests/` | Kontrola dat a návody hry |
| `docs/format-dat.md` | Jak se píše scéna |
