# Fiebre Minera

Juego de Roblox: eres un minero en una mina profunda y compartida por todo el servidor.
Abres camino con tu pico (o con dinamita), buscas minerales, los cargas hasta la salida y
se los vendes al millonario. Con el dinero mejoras tu pico, compras dinamita y mejoras tu
banca de pesas en el campamento.

El diseño completo está en [`DISENO.md`](DISENO.md). Los valores de balance irán en
[`src/shared/Config.luau`](src/shared/Config.luau).

**Estado:** solo la base del proyecto (Rojo y scripts mínimos). La mina todavía no existe.

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
4. Pulsa **Play**. En la salida debe aparecer `[Fiebre Minera] Servidor listo` y `[Fiebre Minera] Cliente listo`.

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
  shared/   Config (balance; por ahora vacío)
  server/   Main (punto de entrada del servidor)
  client/   Main (punto de entrada del cliente)
```
