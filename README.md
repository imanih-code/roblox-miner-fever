# Fiebre Minera

Juego de Roblox: eres un minero en una mina profunda y compartida por todo el servidor.
Abres camino con tu pico (o con dinamita), buscas minerales, los cargas hasta la salida y
se los vendes al millonario. Con el dinero mejoras tu pico, compras dinamita y mejoras tu
banca de pesas en el campamento.

El diseño completo está en [`DISENO.md`](DISENO.md). Todos los valores de balance (capas,
minerales, precios, pico, mochila, lámpara) están en
[`src/shared/Config.luau`](src/shared/Config.luau).

## Qué hay jugable

- **Alta montaña helada** (inspirada en los pueblos mineros de los Andes): un valle de tierra
  y nieve rodeado de cerros escarpados, con nevada, bruma fría y un glaciar arriba. Pueblo de
  casitas con techo de calamina, nieve en los techos, ventanas encendidas y chimeneas con humo.
- **Campamento:** apareces mirando hacia la boca de la mina, con una fogata y el puesto del
  millonario (traje, sombrero de copa, cadena de oro y dos guardaespaldas).
- **Casco minero:** todos llevan casco amarillo con lámpara al frente; alumbra hacia donde miras.
- **La mina:** se entra a pie por un marco de madera en el acantilado; adentro una rampa con
  faroles baja a una galería de inicio. Bajo tierra se apaga el cielo y solo alumbran las
  lámparas y los faroles.
  - **Superficie** (piedra, cualquier pico): carbón y cobre.
  - **Cuevas** (roca dura, pide pico de piedra): hierro, azufre y plata.
  - **Roca imposible** (basalto): manchas y bordes que ningún pico rompe.
  - Solo se pica dentro de la zona de la mina: los cerros y el valle no se rompen.
- **Pico:** clic para picar donde apuntas (alcance 12 studs). Cada golpe borra un poco de
  roca. Las piezas de mineral necesitan varios golpes y van a la mochila.
  - Cinco niveles con su skin: madera → piedra → hierro → oro → diamante. Cada uno pica más
    rápido y aguanta más. El de piedra ya rompe la roca dura de Cuevas.
  - **Durabilidad:** cada golpe gasta 1. Con 0 el pico no pica hasta repararlo.
- **El herrero** (a la izquierda de la boca de la mina, con su fragua): "Hablar con el
  herrero" abre su menú para **mejorar** el pico, **repararlo** con dinero (según lo gastado)
  o **repararlo con hierro** de la mochila (cada hierro repara 35 %). También vende
  **dinamita**: $40, o $15 si le das un azufre.
- **Dinamita** (hasta 10): con la herramienta en la mano, clic para poner un cartucho donde
  apuntas. La mecha dura 3 s y la explosión abre un hueco grande en cualquier roca de la mina
  (menos la roca imposible), deja los minerales a la vista, empuja a los mineros cercanos sin
  hacerles daño y suelta pedruscos que ruedan y pueden tapar túneles. Los pedruscos se rompen
  con 2 golpes de pico y se limpian solos al minuto. Solo se usa dentro de la mina.
- **Mochila:** 12 minerales. El HUD muestra dinero, mochila, pico con su durabilidad,
  dinamita y profundidad.
- **El millonario:** "Vender minerales" junto a su mostrador vende toda la mochila.
- Los minerales Raros o mejores se anuncian a todo el servidor.
- Se guardan el dinero, el pico (nivel y durabilidad) y la dinamita. La mochila no: lo que
  no vendas se pierde al salir.

**Todavía no:** carbón como combustible de la lámpara, minerales grandes en las manos, capas
más hondas (Profundo, Magma, Núcleo), derrumbe que regenera la mina, tiendas y banca de
pesas, sabotaje.

## Preparar el entorno

1. **Instala Rokit**, el gestor de herramientas. En PowerShell:
   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```
   Cierra y vuelve a abrir la terminal.
2. **Instala Rojo** (versión fijada en `rokit.toml`) y su plugin de Studio, desde la carpeta del repo:
   ```powershell
   rokit install
   rojo plugin install
   ```
   Si ya los instalaste para otro proyecto (por ejemplo Ajolotario), no hace falta repetirlo.
3. **Conecta Studio con Claude Code (opcional).** En Studio abre **Assistant → … → Manage MCP Servers** y activa
   **Enable Studio as MCP server**. El repo trae `.mcp.json`; Claude Code pide aprobarlo al abrir una sesión nueva.

## Jugar en Studio

1. Desde la carpeta del repo:
   ```powershell
   rojo serve
   ```
   Este proyecto usa el puerto **34873** (fijado en `default.project.json`), para no chocar con
   Ajolotario, que usa el 34872. Puedes tener los dos `rojo serve` abiertos a la vez.
2. En Roblox Studio abre un lugar nuevo (plantilla **Baseplate**).
3. En la pestaña **Plugins → Rojo**, cambia el puerto a **34873** y pulsa **Connect**. El código se
   sincroniza solo mientras `rojo serve` siga abierto.
4. **Una sola vez:** en el Explorer selecciona **Workspace → Terrain** y en sus propiedades
   desmarca **Decoration** (el pasto alto tapa la vista). Los scripts no pueden cambiarlo, así
   que se queda guardado en el lugar.
5. Pulsa **Play**. En la salida debe aparecer `[Fiebre Minera] Mina lista con ... piezas de mineral`,
   `Servidor listo` y `Cliente listo`. El mapa (terreno, mina y millonario) se construye al
   arrancar el servidor; la Baseplate de la plantilla se quita sola.

Pruebas rápidas en Studio (barra de comandos con el juego corriendo):
`workspace:SetAttribute("DarDinero", 500)` (servidor: dinero a todos),
`workspace:SetAttribute("PonerDurabilidad", 3)` (servidor: durabilidad del pico de todos),
`workspace:SetAttribute("PruebaDinamita", Vector3.new(x, y, z))` (cliente: pone la dinamita
ahí, con la dinamita en la mano) y
`workspace:SetAttribute("PruebaPicar", Vector3.new(x, y, z))` (cliente: pica hacia ese punto
como si fuera un clic, con el pico en la mano).

Para probar con varios jugadores: **Test → Clients and Servers** con 2 o más jugadores.

Para guardar progreso en Studio (cuando exista el guardado): **File → Game Settings → Security →
Enable Studio Access to API Services** (hace falta publicar el lugar primero).

Para generar un archivo de lugar sin Studio abierto:
```powershell
rojo build -o FiebreMinera.rbxlx
```

**Importante:** la fuente de verdad es `src/`. No edites los scripts en Studio: Rojo los sobrescribe.

## Estructura

```
src/
  shared/   Config (balance), Remotes, Format
  server/   Main, PlayerData (guardado), MapaBuilder (cerros, valle, mina, entrada, cielo),
            Pueblo (casitas), Casco (casco con lámpara),
            Vetas (piezas de mineral), PicoService (pico, golpes y durabilidad), Mochila,
            DinamitaService (dinamita, explosión y pedruscos),
            Npc (piezas para armar NPC), Millonario, Herrero (mejorar y reparar)
  client/   Main, Hud (estado y avisos), PicoCliente (clic, chispas y sonido), DinamitaCliente,
            HerreroMenu,
            Ambiente (nevada arriba, oscuridad bajo tierra)
```
