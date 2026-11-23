"""Adds Spanish (Latin American, with articles) to content/words.json and
writes content/spanish_review.csv for a native speaker to check.

Run from vocab-app/:  python3 tool/add_spanish.py
Safe to re-run: it overwrites the "es" entries each time.
"""

import csv
import json

# id: (word with article, fact, note for the reviewer)
ES = {
    "cat": ("el gato", "El gato dice miau.", ""),
    "dog": ("el perro", "El perro mueve la cola cuando está feliz.", ""),
    "cow": ("la vaca", "La vaca nos da leche.", ""),
    "pig": ("el cerdo", "El cerdo tiene la nariz redonda y rosada.", "also: el puerco, el cochino"),
    "duck": ("el pato", "El pato puede nadar y volar.", ""),
    "hen": ("la gallina", "La gallina pone huevos.", ""),
    "fish": ("el pez", "El pez vive en el agua.", "live fish = pez; as food = pescado"),
    "bird": ("el pájaro", "El pájaro tiene plumas y alas.", ""),
    "horse": ("el caballo", "El caballo corre muy rápido.", ""),
    "sheep": ("la oveja", "Las ovejas nos dan lana.", ""),
    "goat": ("la cabra", "A la cabra le gusta trepar.", ""),
    "rabbit": ("el conejo", "El conejo tiene orejas largas.", ""),
    "lion": ("el león", "El león tiene una gran melena.", ""),
    "monkey": ("el mono", "Al mono le encanta trepar árboles.", "Mexico also: el chango"),
    "elephant": ("el elefante", "El elefante tiene una trompa larga.", ""),
    "frog": ("la rana", "La rana salta muy lejos.", ""),
    "whale": ("la ballena", "La ballena es el animal más grande del mar.", ""),
    "dolphin": ("el delfín", "El delfín es muy inteligente.", ""),
    "shark": ("el tiburón", "El tiburón tiene muchos dientes filosos.", ""),
    "octopus": ("el pulpo", "El pulpo tiene ocho brazos.", ""),
    "crab": ("el cangrejo", "El cangrejo camina de lado.", ""),
    "shrimp": ("el camarón", "El camarón es pequeño y vive en el mar.", "Spain: la gamba"),
    "turtle": ("la tortuga", "La tortuga lleva su caparazón en la espalda.", ""),
    "seal": ("la foca", "La foca nada y descansa en la tierra.", ""),
    "shell": ("la concha", "Puedes encontrar conchas en la playa.", "also: el caracol de mar"),
    "lobster": ("la langosta", "La langosta tiene dos pinzas grandes.", ""),
    "bee": ("la abeja", "La abeja hace miel.", ""),
    "ant": ("la hormiga", "Las hormigas trabajan juntas.", ""),
    "butterfly": ("la mariposa", "La mariposa tiene alas de colores.", ""),
    "ladybug": ("la catarina", "La catarina es roja con puntos negros.", "Mexico: catarina; elsewhere: mariquita, vaquita de San Antonio"),
    "spider": ("la araña", "La araña teje una telaraña.", ""),
    "snail": ("el caracol", "El caracol se mueve muy despacio.", ""),
    "worm": ("el gusano", "El gusano vive en la tierra.", "earthworm: la lombriz"),
    "beetle": ("el escarabajo", "El escarabajo tiene un caparazón duro.", ""),
    "cricket": ("el grillo", "El grillo canta de noche.", ""),
    "fly": ("la mosca", "La mosca zumba por todos lados.", ""),
    "apple": ("la manzana", "La manzana crece en un árbol.", ""),
    "banana": ("el plátano", "El plátano es largo y amarillo.", "Mexico: plátano; elsewhere: banana, banano, guineo"),
    "orange": ("la naranja", "La naranja es muy jugosa.", ""),
    "grape": ("la uva", "Las uvas crecen en racimos.", ""),
    "egg": ("el huevo", "El huevo se puede hervir o freír.", ""),
    "bread": ("el pan", "El pan se hace con trigo.", ""),
    "milk": ("la leche", "La leche ayuda a tener huesos fuertes.", ""),
    "carrot": ("la zanahoria", "La zanahoria crece bajo la tierra.", ""),
    "pear": ("la pera", "La pera es dulce y jugosa.", ""),
    "lemon": ("el limón", "El limón sabe ácido.", ""),
    "cherry": ("la cereza", "La cereza es pequeña y roja.", ""),
    "strawberry": ("la fresa", "La fresa tiene semillitas por fuera.", "Argentina/Chile: la frutilla"),
    "corn": ("el maíz", "El maíz es amarillo y crece alto.", "corn on the cob in Mexico: el elote"),
    "cheese": ("el queso", "El queso se hace con leche.", ""),
    "cake": ("el pastel", "Comemos pastel en los cumpleaños.", "also: la torta, el bizcocho"),
    "pizza": ("la pizza", "La pizza es redonda y se corta en rebanadas.", ""),
    "eye": ("el ojo", "Ves con los ojos.", ""),
    "ear": ("la oreja", "Oyes con las orejas.", ""),
    "nose": ("la nariz", "Hueles con la nariz.", ""),
    "mouth": ("la boca", "Comes y hablas con la boca.", ""),
    "hand": ("la mano", "Tienes cinco dedos en cada mano.", ""),
    "foot": ("el pie", "Caminas con los pies.", ""),
    "leg": ("la pierna", "Las piernas te ayudan a correr.", ""),
    "tooth": ("el diente", "Lávate los dientes todos los días.", ""),
    "arm": ("el brazo", "Abrazas con los brazos.", ""),
    "tongue": ("la lengua", "Saboreas con la lengua.", ""),
    "bone": ("el hueso", "Los huesos hacen fuerte tu cuerpo.", ""),
    "brain": ("el cerebro", "Piensas con el cerebro.", ""),
    "hat": ("el sombrero", "El sombrero te protege del sol.", ""),
    "shoe": ("el zapato", "Los zapatos protegen tus pies.", ""),
    "shirt": ("la camisa", "La camisa tiene mangas.", ""),
    "dress": ("el vestido", "El vestido es una sola pieza de ropa.", ""),
    "sock": ("el calcetín", "Usas calcetines dentro de los zapatos.", "also: la media"),
    "coat": ("el abrigo", "El abrigo te mantiene caliente.", "Mexico also: la chamarra"),
    "scarf": ("la bufanda", "La bufanda te calienta el cuello.", ""),
    "glove": ("el guante", "Los guantes te calientan las manos.", ""),
    "boot": ("la bota", "Las botas mantienen secos tus pies.", ""),
    "cap": ("la gorra", "La gorra te da sombra en los ojos.", ""),
    "pants": ("los pantalones", "Los pantalones cubren tus piernas.", ""),
    "glasses": ("los lentes", "Los lentes te ayudan a ver mejor.", "also: los anteojos, las gafas"),
    "cup": ("la taza", "Bebes de una taza.", ""),
    "bed": ("la cama", "Duermes en una cama.", ""),
    "chair": ("la silla", "Te sientas en una silla.", ""),
    "door": ("la puerta", "Abres la puerta para entrar.", ""),
    "key": ("la llave", "La llave abre una cerradura.", ""),
    "couch": ("el sofá", "El sofá es un asiento suave para muchos.", "also: el sillón"),
    "window": ("la ventana", "Puedes mirar afuera por la ventana.", ""),
    "clock": ("el reloj", "El reloj nos dice la hora.", ""),
    "bath": ("la tina", "Te bañas en la tina.", "also: la bañera"),
    "broom": ("la escoba", "La escoba barre el piso.", ""),
    "spoon": ("la cuchara", "Comes sopa con una cuchara.", ""),
    "candle": ("la vela", "La vela da luz.", ""),
    "book": ("el libro", "El libro tiene muchas páginas.", ""),
    "pencil": ("el lápiz", "Escribes con un lápiz.", ""),
    "pen": ("la pluma", "La pluma escribe con tinta.", "Mexico: pluma; elsewhere: el bolígrafo, el lapicero"),
    "bag": ("la mochila", "Llevas tus libros en la mochila.", "picture is a school bag"),
    "scissors": ("las tijeras", "Las tijeras cortan papel.", ""),
    "ruler": ("la regla", "La regla mide qué tan largas son las cosas.", ""),
    "crayon": ("el crayón", "Los crayones son de muchos colores.", "also: la crayola"),
    "computer": ("la computadora", "La computadora nos ayuda a aprender.", "Spain: el ordenador"),
    "globe": ("el globo terráqueo", "El globo terráqueo es un mapa redondo de la Tierra.", "not 'el globo' (= balloon)"),
    "paint": ("la pintura", "Puedes pintar un dibujo.", ""),
    "ball": ("la pelota", "Puedes patear o lanzar una pelota.", "also: el balón"),
    "kite": ("el papalote", "El papalote vuela con el viento.", "Mexico: papalote; elsewhere: la cometa, el barrilete"),
    "teddy": ("el osito de peluche", "El osito de peluche es suave para abrazar.", ""),
    "balloon": ("el globo", "El globo está lleno de aire.", ""),
    "gift": ("el regalo", "El regalo es una sorpresa para alguien.", ""),
    "puzzle": ("el rompecabezas", "Juntas las piezas del rompecabezas.", ""),
    "dice": ("los dados", "Los dados tienen puntos en cada lado.", ""),
    "robot": ("el robot", "El robot es una máquina.", ""),
    "yoyo": ("el yoyo", "El yoyo sube y baja.", ""),
    "skateboard": ("la patineta", "La patineta tiene cuatro ruedas.", "Spain: el monopatín"),
    "car": ("el carro", "El carro va por la calle.", "Spain: el coche; also: el auto"),
    "bus": ("el autobús", "El autobús lleva a mucha gente.", "also: el camión (Mexico), la guagua"),
    "train": ("el tren", "El tren va sobre las vías.", ""),
    "plane": ("el avión", "El avión vuela en el cielo.", ""),
    "boat": ("el bote", "El bote flota en el agua.", "also: la lancha"),
    "bike": ("la bicicleta", "La bicicleta tiene dos ruedas.", ""),
    "truck": ("el camión", "El camión lleva cosas pesadas.", ""),
    "ship": ("el barco", "El barco navega en el mar.", ""),
    "rocket": ("el cohete", "El cohete vuela al espacio.", ""),
    "scooter": ("el scooter", "Empujas el scooter con un pie.", "unsure: Mexico also patín del diablo; Spain el patinete"),
    "tractor": ("el tractor", "El tractor trabaja en la granja.", ""),
    "helicopter": ("el helicóptero", "El helicóptero tiene aspas que giran.", ""),
    "sun": ("el sol", "El sol nos da luz.", ""),
    "moon": ("la luna", "La luna brilla de noche.", ""),
    "star": ("la estrella", "Las estrellas brillan en el cielo de noche.", ""),
    "cloud": ("la nube", "Las nubes flotan en el cielo.", ""),
    "rain": ("la lluvia", "La lluvia ayuda a crecer a las plantas.", ""),
    "tree": ("el árbol", "Los árboles nos dan sombra.", ""),
    "flower": ("la flor", "Las abejas visitan las flores.", ""),
    "leaf": ("la hoja", "Casi todas las hojas son verdes.", ""),
    "rainbow": ("el arcoíris", "El arcoíris tiene muchos colores.", ""),
    "snow": ("la nieve", "La nieve es fría y blanca.", ""),
    "fire": ("el fuego", "El fuego quema. ¡Aléjate!", ""),
    "mountain": ("la montaña", "La montaña es muy alta.", ""),
    "cactus": ("el cactus", "El cactus crece en el desierto.", ""),
    "mushroom": ("el hongo", "Algunos hongos no se pueden comer.", "also: el champiñón (Spain)"),
    "drum": ("el tambor", "Tocas el tambor para hacer ritmo.", ""),
    "guitar": ("la guitarra", "La guitarra tiene cuerdas.", ""),
    "piano": ("el piano", "El piano tiene teclas blancas y negras.", ""),
    "trumpet": ("la trompeta", "Soplas para tocar la trompeta.", ""),
    "violin": ("el violín", "El violín se toca con un arco.", ""),
    "bell": ("la campana", "La campana suena.", ""),
    "microphone": ("el micrófono", "El micrófono hace tu voz más fuerte.", ""),
    "radio": ("el radio", "El radio toca música.", "the device: el radio (Mexico) / la radio (Spain, others)"),
    "headphones": ("los audífonos", "Escuchas con los audífonos.", "also: los auriculares (Spain)"),
}

GROUPS = {
    "animals": ("Animals", "Animales"),
    "sea": ("Sea", "Mar"),
    "bugs": ("Bugs", "Bichos"),
    "food": ("Food", "Comida"),
    "body": ("Body", "Cuerpo"),
    "clothes": ("Clothes", "Ropa"),
    "home": ("Home", "Casa"),
    "school": ("School", "Escuela"),
    "play": ("Play", "Juegos"),
    "transport": ("Transport", "Transporte"),
    "nature": ("Nature", "Naturaleza"),
    "music": ("Music", "Música"),
}

path = "content/words.json"
data = json.load(open(path, encoding="utf-8"))
ids = [w["id"] for w in data["words"]]
missing = set(ids) - ES.keys()
extra = ES.keys() - set(ids)
assert not missing and not extra, (missing, extra)
assert set(data["categories"]) == GROUPS.keys()

data["languages"] = ["en", "es"]
data["categoryNames"] = {c: {"en": en, "es": es} for c, (en, es) in GROUPS.items()}
for w in data["words"]:
    word, fact, _ = ES[w["id"]]
    w["text"]["es"] = word
    w["fact"]["es"] = fact
    w["audio"]["es"] = None

# Keep "words" last so the file reads top-down.
ordered = {k: v for k, v in data.items() if k != "words"}
ordered["words"] = data["words"]
with open(path, "w", encoding="utf-8") as f:
    json.dump(ordered, f, ensure_ascii=False, indent=2)
    f.write("\n")

with open("content/spanish_review.csv", "w", encoding="utf-8-sig", newline="") as f:
    out = csv.writer(f)
    out.writerow(["group", "id", "English", "Spanish", "English fact",
                  "Spanish fact", "note", "OK? / correction"])
    for c, (en, es) in GROUPS.items():
        out.writerow(["(group name)", c, en, es, "", "", "", ""])
    for w in data["words"]:
        word, fact, note = ES[w["id"]]
        out.writerow([w["category"], w["id"], w["text"]["en"], word,
                      w["fact"]["en"], fact, note, ""])

print(f"added Spanish to {len(ids)} words; wrote content/spanish_review.csv")
