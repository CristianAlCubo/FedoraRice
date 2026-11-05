import QtQuick

// Recorta lo que quede a la izquierda del borde de la sidebar. Los paneles que "salen" de la sidebar
// se montan aquí (`parent: sideClip`, x: 0): así nunca dibujan encima de ella y, al abrir, parecen
// emerger desde debajo de la barra. Debe ser hijo directo de una ventana a pantalla completa (o que arranque en x=0).
Item {
    clip: true
    x: Theme.sidebarW
    y: 0
    width: parent ? parent.width - Theme.sidebarW : 0
    height: parent ? parent.height : 0
}
