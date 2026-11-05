-- Monitores de ESTA máquina. install.sh lo crea una sola vez y nunca lo vuelve a pisar: edítalo a gusto.
-- Nombres de las salidas: `hyprctl monitors` (DP-1, HDMI-A-1, eDP-1…).
-- Si una salida de aquí no existe, no pasa nada: hyprland.lua tiene una regla comodín que enciende
-- cualquier pantalla con su mejor tasa de refresco.
--   main / side: monitores de los "grupos" de escritorios (SUPER+1..3 muestra el grupo en ambos).
--                Pon side = nil si solo tienes una pantalla.
return {
  main = "DP-2",   -- LG UltraGear (principal, izquierda)
  side = "DP-1",   -- Samsung (secundario, derecha)
  rules = {
    { output = "DP-2", mode = "2560x1440@144", position = "0x0",    scale = 1 },
    { output = "DP-1", mode = "preferred",     position = "2560x0", scale = 1 },
  },
}
