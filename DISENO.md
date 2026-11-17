# Fiebre Minera — documento de diseño

Juego de Roblox: eres un minero en una mina profunda y compartida por todo el servidor.
Abres camino con tu pico (o con dinamita), buscas minerales, los cargas hasta la salida y
se los vendes al millonario. Con el dinero mejoras tu pico, compras dinamita y mejoras tu
banca de pesas en el campamento para picar minerales más rápido y cargarlos mejor.
Entre mineros hay sabotaje: tirarle el mineral al que lo carga, tapar túneles con dinamita
y encargos secretos del millonario.

Principio de diseño: **mecánicas simples**. Todo lo que se farmea aparte tiene que servir
para lo principal (picar, cargar y vender minerales).

---

## 1. Bucle principal

1. Sales de tu tienda en el campamento y entras a la mina.
2. Picas (o dinamitas) para abrir camino y buscar vetas de minerales.
3. Cargas los minerales: los chicos en la mochila, los grandes en las manos.
4. Llegas a la salida y se los vendes al millonario.
5. Con el dinero: mejoras o reparas el pico con el herrero, compras dinamita y mejoras tu
   banca de pesas.
6. Mientras descansas en el campamento, tu personaje entrena solo y gana Fuerza.

---

## 2. La mina

- **Excavable de verdad.** Está hecha con el terreno de Roblox (vóxeles): picar o dinamitar
  borra terreno (`Terrain:FillBall(..., Enum.Material.Air)`), así que cada jugador abre sus
  propios túneles. No hay caminos fijos.
- **Compartida por el servidor:** lo que uno abre, otro lo puede usar.
- **Oscura:** bajo tierra no hay luz; tu lámpara alumbra alrededor.
- **Capas por profundidad** (más hondo = minerales más valiosos, roca más dura):

| Capa | Minerales | Pico mínimo |
|---|---|---|
| Superficie | carbón, cobre | madera |
| Cuevas | hierro, plata, azufre | piedra |
| Profundo | oro, amatista | hierro |
| Magma | rubí, esmeralda, diamante | oro |
| Núcleo | minerales míticos que brillan | diamante |

- **Tipos de roca:**
  - **Piedra normal:** se pica con cualquier pico; tarda según el nivel del pico.
  - **Roca dura:** solo la pica un pico de cierto nivel (se ve distinta por capa).
  - **Roca imposible:** basalto negro con vetas, visiblemente diferente. Ningún pico la
    rompe; la dinamita tampoco. Obliga a rodear.
- **Derrumbe (renovación):** cada cierto tiempo (por ejemplo, 20 min) el servidor avisa
  "derrumbe en 2 min" y la mina se regenera con minerales nuevos. Así nunca se acaba y hay un
  momento de "último viaje" antes del derrumbe.

---

## 3. Herramientas

### Pico
- Sirve para picar piedra y minerales.
- **Nivel del pico:** da **velocidad de picado** y **durabilidad** (vida útil), parecido a
  Minecraft. Cada nivel tiene su **skin** para que se note cuál es mejor:
  madera → piedra → hierro → oro → diamante (y quizá uno mítico).
- **Durabilidad:** cada golpe la gasta. Con 0 ya no pica: hay que repararlo con el herrero
  (cobra dinero) o con hierro que hayas minado.
- Se mejora con el herrero (por ahora solo con dinero; ver sección 11).

### Dinamita
- Se compra; se acumula en tu inventario si la llevas.
- **Precio medio:** ni tan barata como para dinamitar la mina entera, ni tan cara como para
  usarla una vez en la vida.
- **Qué hace:**
  - Abre un hueco grande (no rompe la roca imposible).
  - **Suelta pedruscos con física** que ruedan y pueden **tapar túneles**: sirve para avanzar
    rápido o para trolear a otros.
- **Para que el troleo no frustre:** los derrumbes de dinamita en el túnel principal se
  limpian solos después de un rato.
- El herrero también la fabrica más barata si le llevas azufre (pólvora).

### Lámpara
- Alumbra alrededor tuyo en la oscuridad.
- Usa carbón como combustible (se recarga con carbón minado).
- Se mejora: más alcance y más duración.

### Mochila
- Espacio limitado para minerales chicos. Se mejora para llevar más.
- Los minerales grandes (gemas, míticos) **no caben**: se cargan en las manos, se ven
  brillando y te hacen más lento.

---

## 4. Minerales

- Muchos tipos, cada uno con su rareza. Más raro = más valioso y más vistoso (brillo,
  partículas, tamaño).
- Cuando alguien saca uno raro, **el servidor avisa a todos**.
- **Los comunes alimentan lo principal** (para que farmearlos valga la pena):
  - **Carbón** → combustible de la lámpara.
  - **Hierro** → reparar el pico sin pagar al herrero.
  - **Azufre** → dinamita más barata con el herrero.
- Los raros son los que dan dinero de verdad.

---

## 5. La salida de la mina

- **El millonario:** NPC con skin de rico (traje, sombrero, cadena de oro) en su puesto,
  con **guardaespaldas**. Le llevas minerales y te paga. Si llegas con el mineral, cobras.
- **El herrero:** mejora y repara el pico, vende dinamita.
- (Opcional) Tienda de mejoras: lámpara, mochila, botas, casco.

---

## 6. El campamento

- Afuera de la mina, junto al millonario. **Cada jugador tiene su tienda**, chiquitas y muy
  juntas, para que todos se vean.
- En tu tienda está tu **banca de pesas**.

### Banca de pesas (Fuerza)
- **Un solo ejercicio para todos: press de banca.**
- **El personaje entrena solo** mientras está en la banca y gana Fuerza por segundo.
- **Mejora de la banca:** solo cambia la skin de la misma máquina, y más nivel = más Fuerza
  por segundo. Nada más (no cambia el ejercicio).
  Ejemplo de skins: banca de tablas con piedras → banca de metal con discos → banca
  cromada → banca de oro.
- **Anti-AFK:**
  - **Clics de bonus eventuales:** de vez en cuando aparece algo para clickear que da un
    extra de Fuerza (opcional para el jugador).
  - **Evento de cansancio:** cada ciertos minutos aparece un botón en **cualquier parte de
    la pantalla**. Si no le das clic a tiempo, tu personaje **se baja de la banca** y deja
    de entrenar.
- **Qué da la Fuerza** (solo en minerales; la piedra no cambia):
  - **Picas minerales más rápido** (por ejemplo, +3 % por nivel).
  - **Cargas mejor:** el mineral pesado te frena menos y puedes cargar piezas más grandes.
  - **No sube la velocidad base ni el picado de piedra.** Así un jugador nuevo abre camino
    igual que uno viejo y la persecución sigue siendo justa.
- **Curva:** cada nivel de Fuerza cuesta más que el anterior; tope razonable (por ejemplo,
  nivel 50).
- Se ve: título sobre la cabeza (Novato, Picador, Fortachón, Bestia, Titán) y tablero de
  los más fuertes en el campamento.

---

## 7. Moverse por la mina

- **Sin velocidad base farmeable** (rompería la persecución).
- **Sprint con resistencia:** un sprint corto que gasta energía; se mejora cuánto dura y
  qué tan rápido se recupera.
- **Atajos:** escaleras, cuerdas, rieles con carrito y elevadores por capa (se desbloquean
  con dinero). La dinamita de otros los puede volar.
- **Botas y casco** (opcionales): trepar más rápido / aguantar mejor explosiones y
  derrumbes.

---

## 8. Sabotaje (inspirado en Saboteur, versión simple)

- **Golpe con el pico:** si le pegas a un minero que **carga un mineral en las manos**, lo
  suelta y cualquiera lo puede agarrar.
- **Dinamita contra otros:** tapar el túnel por donde viene alguien o derrumbarle la salida.
- **Encargos secretos del millonario:** de vez en cuando le susurra a **un solo jugador**:
  "que [fulano] no llegue con su rubí y te pago". Nadie más sabe quién lo recibió.

---

## 9. Qué se guarda entre partidas

Dinero, nivel del pico (y su durabilidad), dinamita guardada, lámpara, mochila, nivel de
la banca, Fuerza, y (opcional) una repisa en tu tienda con tus mejores minerales.

---

## 10. Técnica (Roblox)

- Luau sincronizado con Rojo; la fuente de verdad es `src/`.
- Terreno vóxel para la mina: picar = borrar una esfera chica de terreno en el punto del
  golpe; dinamita = esfera grande + pedruscos sueltos con física.
- Minerales: piezas o modelos incrustados en el terreno (generados por código al construir
  o al regenerar la mina), con brillo y partículas según la rareza.
- Validación en el servidor: el cliente dice dónde pica; el servidor revisa distancia,
  cadencia, nivel del pico, material de la roca y durabilidad.
- Oscuridad: iluminación baja bajo tierra; la lámpara es una luz en el personaje.
- Reutilizable del proyecto anterior (Ajolotario): avisos (toasts), menús, guardado con
  DataStore, avisos al servidor de rarezas, patrón de servicios.

---

## 11. Primera versión jugable (decisiones tomadas)

- **Ambiente:** alta montaña helada, inspirada en La Rinconada (Perú): el campamento está en
  un valle de tierra y nieve rodeado de una cresta baja; al norte, el cerro de la mina con
  glaciar en la cumbre. Nieva, hay bruma fría y un pueblo de casitas con techo de calamina.
- **Mundo de afuera:** para que no se sienta encerrado, detrás de la cresta se ve una meseta
  y una cordillera lejana. Una pared invisible sobre la cresta no deja salir.
- **Oscuridad:** la luz es fija (Ambient negro y sin luz del entorno): bajo la roca está
  oscuro solo, sin cambiar el cielo al entrar o salir de la mina.
- **Mapa:** la mina es un bloque de 160 × 160 studs y unos 90 de hondo, bajo el cerro del
  norte. Se entra a pie por un marco de madera en el acantilado; adentro la rampa baja a una
  galería de inicio. Solo se pica dentro de la zona de la mina; cerros y valle no se rompen.
- **Casco minero:** cada jugador lleva casco amarillo con lámpara al frente (haz hacia donde
  mira y luz suave alrededor).
- **Capas hechas:** Superficie (piedra, carbón y cobre) y Cuevas (roca dura, que pide pico
  de piedra; hierro, azufre y plata). Las de Profundo, Magma y Núcleo vienen después.
- **Picado continuo (como Minecraft):** se mantiene el clic. Lo que picas es un trozo (el
  vóxel apuntado y sus 6 vecinos) que se va achicando a la vista, con barra de progreso,
  hasta romperse. Si sueltas o cambias de trozo, vuelve a quedar entero. Si varios pican lo
  mismo, suman. Tiempo = dureza ÷ poder del pico × cadencia: con madera, la piedra tarda 2 s.
  Durezas: tierra 3, piedra 4, roca dura 8; carbón 3, cobre 4, azufre 5, hierro 6, plata 8.
  Poder de los picos: madera 1, piedra 1.5, hierro 2.2, oro 3, diamante 4.2.
- **Pepitas:** los minerales al romperse caen como pepitas con física; se recogen tocándolas
  (cualquiera puede agarrarlas) y desaparecen a los 3 minutos.
- **Sin xray:** los minerales son solo datos en el servidor hasta que la roca a su alrededor
  se abre; recién ahí aparecen en el mundo.
- **Dinamita:** el hueco es instantáneo (eso la distingue del pico) y deja escombro: 8
  pedruscos que se pican para quitarlos.
- **Mochila:** 12 minerales chicos; no se guarda al salir del juego.
- **Precios iniciales:** carbón $4, cobre $10, azufre $14, hierro $18, plata $45.
- **Lámpara:** por ahora siempre prendida; el carbón como combustible llega después.
- **Herrero:** la mejora del pico cuesta solo dinero (por ahora sin minerales):
  piedra $150, hierro $600, oro $2,000, diamante $6,000. El pico nuevo sale con la
  durabilidad llena.

  | Pico | Golpes/s | Durabilidad | Reparar entero |
  |---|---|---|---|
  | Madera | 2.0 | 150 | $15 |
  | Piedra | 2.4 | 300 | $40 |
  | Hierro | 2.9 | 550 | $120 |
  | Oro | 3.4 | 900 | $300 |
  | Diamante | 4.2 | 1500 | $700 |

  Reparar cobra según lo gastado. Cada hierro de la mochila repara el 35 % del pico.
- **Dinamita:** $40, o $15 más 1 azufre; se cargan hasta 10 y se guardan. Mecha de 3 s,
  hueco de radio 9 en cualquier roca de la mina (incluida la roca dura; nunca la roca
  imposible). No mata: solo empuja. Suelta 8 pedruscos con física que se pican para quitarlos
  y se limpian solos al minuto (máximo 80 en el servidor). Solo se usa dentro de la
  mina.
- **Campamento:** 14 tiendas de pared (lona, techo a dos aguas) en dos filas junto a la
  aparición; cada jugador recibe una libre al entrar. Solo el dueño ve los avisos de su
  banca.
- **Fuerza:** se gana acostado en tu banca (salta para levantarte). Experiencia para subir
  del nivel n: 20 × 1.12ⁿ; tope 50 (unas horas de entrenamiento). Bancas: tablas $0 (1/s),
  metal $300 (2/s), cromada $1,500 (3.5/s), oro $5,000 (6/s). Bonus opcional cada 20–40 s
  (+10 s de experiencia si le das en 4 s). Cansancio cada 2–4 min: 8 s para darle o te bajas.
  Efecto: +3 % de velocidad al picar minerales por nivel (no la roca). Títulos: Novato (0),
  Picador (10), Fortachón (20), Bestia (30), Titán (40); se anuncia al servidor al cambiar.
- **Aún no:** minerales grandes (y cargar mejor con la Fuerza), capas más hondas, derrumbe y
  sabotaje.

---

## 12. Pendiente de decidir

- Nombre final del juego (repo: `roblox-miner-fever`).
- Lista exacta de minerales, precios y rarezas.
- Precio de la dinamita y de cada nivel de pico/banca.
- Cuánto dura una "temporada" de la mina antes del derrumbe.
- Cuántos jugadores por servidor (tamaño de la mina y del campamento).
