#!/usr/bin/env python3
"""Genera los logos e íconos de Mi Plata a partir de los originales.

    python3 scripts/generar-logos.py

Lee `app/assets/branding/originales/` y escribe en `app/assets/branding/`:

  simbolo-color / -negro / -blanco.png   billetera con monedas, sin texto, 1024 px
  logo-horizontal-* / logo-vertical-*    símbolo + el texto "Mi Plata"
  icono-*.png                            piezas del ícono de Android

Las siluetas negra y blanca salen del MISMO canal alfa: tienen la misma forma y
el mismo sitio, así que se pueden intercambiar según el tema. El símbolo a color
sale del logo a color quitándole el fondo azul noche (solo el que está conectado
con el borde: las líneas oscuras internas de la billetera se conservan).

Hace falta Pillow y numpy.
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
ORIGINALES = RAIZ / "app/assets/branding/originales"
SALIDA = RAIZ / "app/assets/branding"
FUENTE = RAIZ / "app/assets/fonts/PlusJakartaSans-Bold.ttf"

AZUL_NOCHE = (5, 13, 30)  # #050D1E
BLANCO_CALIDO = (248, 247, 243)  # #F8F7F3
VERDE_FONDO_OSCURO = (44, 193, 116)  # #2CC174: "Plata" sobre fondos oscuros
VERDE_FONDO_CLARO = (8, 142, 115)  # #088E73: "Plata" sobre fondos claros
LIENZO = 1024


def recorte_ajustado(img: Image.Image) -> Image.Image:
    """Recorta al contenido (todo lo que no es transparente)."""
    caja = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return img.crop(caja)


def con_altura(img: Image.Image, alto: int) -> Image.Image:
    return img.resize((round(img.width * alto / img.height), alto), Image.LANCZOS)


def con_ancho(img: Image.Image, ancho: int) -> Image.Image:
    return img.resize((ancho, round(img.height * ancho / img.width)), Image.LANCZOS)


def centrado(img: Image.Image, fondo=None) -> Image.Image:
    base = Image.new("RGBA", (LIENZO, LIENZO), fondo or (0, 0, 0, 0))
    base.alpha_composite(img, ((LIENZO - img.width) // 2, (LIENZO - img.height) // 2))
    return base


# --- siluetas de un solo color (de la variante negra, que tiene alfa real) ------


def siluetas():
    var = Image.open(ORIGINALES / "variantes-blanco-y-negro.png").convert("RGBA")
    negra = var.crop((var.width // 2, 0, var.width, var.height))
    alfa = np.array(negra.getchannel("A"))
    # La fila vacía que separa el dibujo del texto "Mi Plata".
    filas = (alfa > 20).any(axis=1)
    inicio = int(np.argmax(filas))
    vacia = next(y for y in range(inicio + 200, len(filas)) if not filas[y])
    dibujo = recorte_ajustado(negra.crop((0, 0, negra.width, vacia)))
    a = dibujo.getchannel("A")
    negro = Image.merge("RGBA", (*(Image.new("L", a.size, 0),) * 3, a))
    blanco = Image.merge("RGBA", (*(Image.new("L", a.size, 255),) * 3, a))
    return negro, blanco


# --- símbolo a color: quita el fondo azul noche conectado con el borde -------------


def simbolo_color():
    logo = Image.open(ORIGINALES / "logo-mi-plata.png").convert("RGB")
    # La billetera y las monedas, sin el texto de abajo ni las esquinas negras.
    zona = logo.crop((150, 80, 1110, 780))
    px = np.array(zona).astype(np.float32)
    h, w, _ = px.shape
    dist = np.linalg.norm(px - np.array(AZUL_NOCHE, np.float32), axis=2)

    T0, T1 = 14.0, 46.0  # por debajo de T0 es fondo; entre T0 y T1, borde suave
    candidato = dist < T1
    conectado = np.zeros((h, w), bool)
    cola = deque()
    for x in range(w):
        for y in (0, h - 1):
            if candidato[y, x] and not conectado[y, x]:
                conectado[y, x] = True
                cola.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if candidato[y, x] and not conectado[y, x]:
                conectado[y, x] = True
                cola.append((y, x))
    while cola:
        y, x = cola.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and candidato[ny, nx] and not conectado[ny, nx]:
                conectado[ny, nx] = True
                cola.append((ny, nx))

    alfa = np.full((h, w), 255.0, np.float32)
    rampa = np.clip((dist - T0) / (T1 - T0), 0, 1) * 255
    alfa[conectado] = rampa[conectado]
    # Quita el tinte azul del borde: c = (px - (1-a)*fondo) / a
    a = np.clip(alfa / 255, 1e-3, 1)[..., None]
    fondo = np.array(AZUL_NOCHE, np.float32)
    limpio = np.where(
        conectado[..., None], np.clip((px - (1 - a) * fondo) / a, 0, 255), px
    )
    rgba = np.dstack([limpio, alfa]).astype(np.uint8)
    return recorte_ajustado(Image.fromarray(rgba))


# --- texto "Mi Plata" -----------------------------------------------------------


def logo_con_texto(simbolo, colores, horizontal, alto_simbolo=620):
    """Símbolo + "Mi Plata". [colores] = (color de "Mi ", color de "Plata")."""
    s = con_altura(simbolo, alto_simbolo)
    fuente = ImageFont.truetype(str(FUENTE), round(alto_simbolo * 0.62))
    mi, plata = "Mi ", "Plata"
    ancho_mi = fuente.getlength(mi)
    ancho_total = round(ancho_mi + fuente.getlength(plata))
    ascent, descent = fuente.getmetrics()

    texto = Image.new("RGBA", (ancho_total + 8, ascent + descent + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(texto)
    d.text((4, 4), mi, font=fuente, fill=colores[0])
    d.text((4 + ancho_mi, 4), plata, font=fuente, fill=colores[1])
    texto = recorte_ajustado(texto)

    sep = round(alto_simbolo * 0.12)
    if horizontal:
        w = s.width + sep + texto.width
        h = max(s.height, texto.height)
        lienzo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        lienzo.alpha_composite(s, (0, (h - s.height) // 2))
        lienzo.alpha_composite(texto, (s.width + sep, (h - texto.height) // 2))
    else:
        w = max(s.width, texto.width)
        h = s.height + sep + texto.height
        lienzo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        lienzo.alpha_composite(s, ((w - s.width) // 2, 0))
        lienzo.alpha_composite(texto, ((w - texto.width) // 2, s.height + sep))
    margen = round(min(w, h) * 0.06)
    final = Image.new("RGBA", (w + 2 * margen, h + 2 * margen), (0, 0, 0, 0))
    final.alpha_composite(lienzo, (margen, margen))
    return final


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    negro, blanco = siluetas()
    color = simbolo_color()

    # Símbolos: mismo lienzo y mismo sitio. La silueta y el color son dibujos
    # distintos: se igualan por ALTO para que ocupen lo mismo.
    alto = round(LIENZO * 0.46)
    for nombre, img in (("color", color), ("negro", negro), ("blanco", blanco)):
        centrado(con_altura(img, alto)).save(SALIDA / f"simbolo-{nombre}.png")

    # Logos con texto, recortados al contenido y con margen.
    variantes = {
        "color-fondo-oscuro": (color, (BLANCO_CALIDO, VERDE_FONDO_OSCURO)),
        "color-fondo-claro": (color, (AZUL_NOCHE, VERDE_FONDO_CLARO)),
        "negro": (negro, ((0, 0, 0), (0, 0, 0))),
        "blanco": (blanco, ((255, 255, 255), (255, 255, 255))),
    }
    for nombre, (simbolo, colores) in variantes.items():
        for orient, horizontal in (("horizontal", True), ("vertical", False)):
            logo_con_texto(simbolo, colores, horizontal).save(
                SALIDA / f"logo-{orient}-{nombre}.png"
            )

    # Piezas del ícono de Android. Un ícono adaptable solo muestra el centro
    # (un círculo de 66 de 108 dp): el dibujo tiene que caber ahí.
    ancho_icono = round(LIENZO * 0.55)
    centrado(con_ancho(color, ancho_icono)).save(SALIDA / "icono-primer-plano.png")
    centrado(con_ancho(negro, round(ancho_icono * 0.90))).save(
        SALIDA / "icono-monocromo.png"
    )
    # Ícono clásico (Android viejo): cuadrado completo, sin esquinas redondeadas.
    centrado(con_ancho(color, round(LIENZO * 0.62)), fondo=AZUL_NOCHE + (255,)).convert(
        "RGB"
    ).save(SALIDA / "icono-clasico.png")
    print("listo:", *sorted(p.name for p in SALIDA.glob("*.png")), sep="\n  ")


if __name__ == "__main__":
    main()
