# Lili a hřebec Hrom

Kreslená point-and-click adventura pro Android v Godotu 4.5. Pro děti 8 až 11 let, 23 scén v 7 kapitolách.

## Spuštění

1. Nainstalujte [Godot 4.5](https://godotengine.org/download) (standardní verze, ne .NET).
2. Otevřete složku projektu v Godotu a stiskněte F5.

Bez grafiky se scény kreslí jako placeholdery: barevná plocha s obrysy klikacích míst.

## Ovládání

- Ťuknutí na místo: Lili tam dojde. Ťuknutí na předmět nebo postavu: interakce.
- Přetažení předmětu z inventáře na místo: použití. Na jiný předmět: spojení.
- Ťuknutí na předmět v inventáři: Lili ho popíše.
- Podržení prstu na scéně: zvýrazní všechna klikací místa.
- Tlačítko Rada: šerif napoví, každým stisknutím víc.

## Testy

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

Kontrolují data všech scén a přehrají návody v `tests/walkthroughs/`. Rychlá zkouška celé hry bez okna: `godot --headless --path . -- --smoke`.

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
