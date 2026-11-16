# Fiebre Minera — notas para Claude

- Juego de Roblox en Luau. El diseño completo está en [`DISENO.md`](DISENO.md): léelo antes de empezar cualquier trabajo y actualízalo cuando se decida algo nuevo.
- Principio del usuario: **mecánicas simples**, y todo lo que se farmea aparte debe servir para lo principal (picar, cargar y vender minerales).
- Se sincroniza a Studio con Rojo (`default.project.json`, `rokit.toml`, `src/server`, `src/client`, `src/shared`). La fuente de verdad es `src/`; no edites scripts directamente en Studio, porque Rojo los sobrescribe.
- `rojo serve` de este proyecto usa el puerto **34873** (Ajolotario usa el 34872); en el plugin de Rojo hay que poner ese puerto al conectar.
- Proyecto hermano: `../roblox-farm-steal-fight` (Ajolotario). Ahí hay piezas reutilizables: avisos (Hud.Toast), menús, PlayerData con DataStore, avisos de rarezas al servidor, NPC con HumanoidDescription, ganchos de prueba en Studio. Cópialas y adáptalas; no las enlaces.
- Lecciones del proyecto anterior:
  - Terreno: FillBlock hasta y = -2 deja la superficie en y = 0; FillCylinder solo llena celdas completas (superficie en y = 2). El agua solo llena aire.
  - Rojo a veces no manda a Studio la última de varias ediciones seguidas al mismo archivo: compara el largo de `Source` en Studio con el archivo local antes de probar.
  - Para probar usa el MCP `Roblox_Studio` (Studio abierto, "Enable Studio as MCP server" activado, `rojo serve` corriendo). El teclado simulado no llega al juego: usa ganchos de prueba con atributos de workspace y `ProximityPrompt:InputHoldBegin()` desde el cliente.
  - Las mallas generadas con IA (`generate_mesh`) solo funcionan en modo edición (no durante Play) y viven en el lugar: hay que guardarlo para no perderlas.
  - Algunos emojis no se ven en Roblox (por ejemplo 🪱, ✦, 🌫); prefiere ⭐ 🐛 🛶 🏞.
- Commit solo cuando el usuario lo pida; pedir permiso antes de guardar el lugar en Roblox.
- Textos del juego y comentarios en español.
