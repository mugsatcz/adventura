# Grafika

| Co | Velikost | Název souboru |
| --- | --- | --- |
| Pozadí scény | 1920×1080 px, 16:9, PNG | `art/scenes/<id scény>.png` |
| Popředí scény (volitelné) | 1920×1080 px, průhledné PNG | `art/scenes/<id scény>_fg.png`, v JSON klíč `foreground` |
| Ikona předmětu | 256×256 px, průhledné PNG | `art/items/<id předmětu>.png` |
| Obrázek cutscény | 1920×1080 px, 16:9, PNG | cesta podle `image` v dané cutscéně |

- Spodních asi 150 px zakrývá lišta s inventářem a titulky.
- Lili je sprite ze `art/characters` (stání + 8 snímků chůze doprava, doleva se zrcadlí). Chodí po pásu zhruba y 720 až 900. Na pozadí nemají být postavy ani text.
- Klikací místa jsou v JSON a po vložení nového obrázku se jejich polygony upraví podle něj.
- Obrázek, který není 16:9, se před vložením ořízne.
