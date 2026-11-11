#!/usr/bin/env python
# ============================================================================
#  TP 8 · Generador del informe
# ----------------------------------------------------------------------------
#  Lee docs/informe.md (fuente unica de contenido) y produce docs/informe.pdf.
#
#  Por que existe este script y no dos archivos escritos a mano:
#  un informe en Markdown y un PDF mantenidos por separado se desincronizan en
#  la primera correccion. Aca hay UNA fuente y una conversion reproducible.
#
#  Subconjunto de Markdown soportado (a proposito, chico):
#    # / ## / ###   encabezados
#    ---           separador
#    | a | b |     tablas con fila separadora |---|---|
#    - item        listas
#    **negrita**, `codigo`, *cursiva*
#
#  Uso:
#    python docs/generar_informe.py
# ============================================================================

import re
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, Table, TableStyle,
    KeepTogether,
)

ROOT = Path(__file__).resolve().parent
ORIGEN = ROOT / "informe.md"
DESTINO = ROOT / "informe.pdf"

ANCHO_UTIL = A4[0] - 3.4 * cm

AZUL = colors.HexColor("#1f3a5f")
GRIS = colors.HexColor("#555555")
GRIS_CLARO = colors.HexColor("#eef2f6")
LINEA = colors.HexColor("#c9d3dd")


# ---------------------------------------------------------------------------
#  Estilos
# ---------------------------------------------------------------------------
def estilos():
    base = getSampleStyleSheet()
    return {
        "h1": ParagraphStyle(
            "h1", parent=base["Title"], fontName="Helvetica-Bold",
            fontSize=15, leading=18, textColor=AZUL,
            spaceAfter=2, alignment=TA_LEFT,
        ),
        "h2": ParagraphStyle(
            "h2", parent=base["Heading2"], fontName="Helvetica-Bold",
            fontSize=11.5, leading=14, textColor=AZUL,
            spaceBefore=9, spaceAfter=4, alignment=TA_LEFT, keepWithNext=1,
        ),
        "h3": ParagraphStyle(
            "h3", parent=base["Heading3"], fontName="Helvetica-Bold",
            fontSize=9.6, leading=12, textColor=colors.HexColor("#22303d"),
            spaceBefore=7, spaceAfter=2, keepWithNext=1,
        ),
        "p": ParagraphStyle(
            "p", parent=base["BodyText"], fontName="Helvetica",
            fontSize=8.7, leading=11.4, alignment=TA_JUSTIFY,
            spaceAfter=4,
        ),
        "bullet": ParagraphStyle(
            "bullet", parent=base["BodyText"], fontName="Helvetica",
            fontSize=8.7, leading=11.2, alignment=TA_JUSTIFY,
            leftIndent=11, bulletIndent=3, spaceAfter=2,
        ),
        "cell": ParagraphStyle(
            "cell", parent=base["BodyText"], fontName="Helvetica",
            fontSize=7.2, leading=9.0, alignment=TA_LEFT,
        ),
        "head": ParagraphStyle(
            "head", parent=base["BodyText"], fontName="Helvetica-Bold",
            fontSize=7.2, leading=9.0, textColor=colors.white,
        ),
        "nota": ParagraphStyle(
            "nota", parent=base["BodyText"], fontName="Helvetica-Oblique",
            fontSize=7.6, leading=9.6, textColor=GRIS, alignment=TA_LEFT,
        ),
    }


# ---------------------------------------------------------------------------
#  Inline: **negrita**, `codigo`, *cursiva*
# ---------------------------------------------------------------------------
def inline(texto):
    texto = (texto.replace("&", "&amp;")
                  .replace("<", "&lt;")
                  .replace(">", "&gt;"))
    # Flechas y simbolos fuera de WinAnsi -> equivalentes ASCII.
    texto = texto.replace("\u2192", "-&gt;").replace("\u2264", "<=").replace("\u2265", ">=")
    texto = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", texto)
    texto = re.sub(r"`(.+?)`", r'<font name="Courier" size="7.6">\1</font>', texto)
    texto = re.sub(r"(?<!\*)\*([^*]+?)\*(?!\*)", r"<i>\1</i>", texto)
    return texto


# ---------------------------------------------------------------------------
#  Tabla Markdown -> flowable
# ---------------------------------------------------------------------------
def es_separador(fila):
    return all(re.fullmatch(r":?-{3,}:?", c.strip()) for c in fila if c.strip() != "")


def anchos(filas, total):
    """Ancho proporcional al contenido, con piso por columna.

    El piso no es un numero fijo: tiene que alcanzar para la palabra mas larga
    de la columna. Sin eso, "PostgreSQL" se parte como "PostgreS / QL" y una
    columna de dos letras se escribe en vertical, una letra por linea.
    """
    ncols = len(filas[0])
    largos = [max(len(f[j]) for f in filas) for j in range(ncols)]
    # Exponente < 1: comprime la diferencia entre columnas anchas y angostas.
    pesos = [max(l, 4) ** 0.75 for l in largos]
    suma = sum(pesos)
    ancho = [total * p / suma for p in pesos]

    # Piso: el ancho real de la palabra mas larga de la columna, medido con la
    # fuente en la que se va a dibujar. Estimar "4 pt por caracter" no alcanza:
    # Courier 7.6 mide 4.56 pt por caracter y parte el nombre de un archivo.
    piso = []
    for j in range(ncols):
        maximo = 0.0
        for f in filas:
            for palabra in f[j].replace("*", "").replace("`", "").split():
                maximo = max(
                    maximo,
                    stringWidth(palabra, "Helvetica-Bold", 7.2),
                    stringWidth(palabra, "Courier", 7.6),
                )
        piso.append(max(1.25 * cm, maximo + 9))

    for _ in range(4):
        deficit = sum(max(0.0, piso[j] - ancho[j]) for j in range(ncols))
        if deficit <= 0.5:
            break
        ancho = [max(ancho[j], piso[j]) for j in range(ncols)]
        holgadas = [j for j in range(ncols) if ancho[j] > piso[j] + 0.01]
        base = sum(ancho[j] for j in holgadas)
        if base <= 0:
            break
        for j in holgadas:
            ancho[j] -= deficit * (ancho[j] / base)

    return ancho


def construir_tabla(filas, est, total=ANCHO_UTIL):
    cabecera, cuerpo = filas[0], filas[1:]
    datos = [[Paragraph(inline(c), est["head"]) for c in cabecera]]
    for f in cuerpo:
        datos.append([Paragraph(inline(c), est["cell"]) for c in f])

    tabla = Table(datos, colWidths=anchos(filas, total), repeatRows=1, hAlign="LEFT")
    tabla.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), AZUL),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.4, LINEA),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, GRIS_CLARO]),
        ("LEFTPADDING", (0, 0), (-1, -1), 3.5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3.5),
        ("TOPPADDING", (0, 0), (-1, -1), 2.6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2.6),
    ]))
    return tabla


# ---------------------------------------------------------------------------
#  Parser del Markdown
# ---------------------------------------------------------------------------
def parsear(md, est):
    lineas = md.replace("\r\n", "\n").split("\n")
    flujo = []
    i = 0
    while i < len(lineas):
        linea = lineas[i].rstrip()

        if not linea.strip():
            i += 1
            continue

        if linea.startswith("### "):
            flujo.append(Paragraph(inline(linea[4:]), est["h3"]))
            i += 1
            continue
        if linea.startswith("## "):
            flujo.append(Paragraph(inline(linea[3:]), est["h2"]))
            i += 1
            continue
        if linea.startswith("# "):
            flujo.append(Paragraph(inline(linea[2:]), est["h1"]))
            i += 1
            continue
        if linea.strip() == "---":
            flujo.append(Spacer(1, 4))
            i += 1
            continue

        # Tabla
        if linea.lstrip().startswith("|"):
            bloque = []
            while i < len(lineas) and lineas[i].lstrip().startswith("|"):
                bloque.append(lineas[i].strip())
                i += 1
            crudas = [[c.strip() for c in b.strip("|").split("|")] for b in bloque]
            filas = [f for f in crudas if not es_separador(f)]
            if filas:
                # KeepTogether: una tabla que empieza con una sola fila al pie
                # de una pagina se lee peor que la tabla entera en la siguiente.
                flujo.append(KeepTogether([construir_tabla(filas, est)]))
                flujo.append(Spacer(1, 5))
            continue

        # Lista (con vinetas o numerada) con lineas de continuacion
        if re.match(r"^\s*([-*]|\d+\.)\s+", linea):
            items = []
            while i < len(lineas):
                actual = lineas[i]
                mv = re.match(r"^\s*[-*]\s+(.*)$", actual)
                mn = re.match(r"^\s*(\d+)\.\s+(.*)$", actual)
                if mv:
                    items.append(["\u2022", mv.group(1).strip()])
                    i += 1
                elif mn:
                    items.append([mn.group(1) + ".", mn.group(2).strip()])
                    i += 1
                elif (actual.strip()
                      and not actual.lstrip().startswith(("#", "|", "---"))):
                    # Continuacion del item anterior (el Markdown corta la
                    # linea por ancho, no porque el item termine).
                    items[-1][1] += " " + actual.strip()
                    i += 1
                else:
                    break
            for marcador, texto in items:
                flujo.append(Paragraph(inline(texto), est["bullet"], bulletText=marcador))
            flujo.append(Spacer(1, 3))
            continue

        # Parrafo: juntar hasta linea en blanco / bloque
        parrafo = [linea.strip()]
        i += 1
        while (i < len(lineas) and lineas[i].strip()
               and not lineas[i].lstrip().startswith(("#", "|", "---"))
               and not re.match(r"^\s*([-*]|\d+\.)\s+", lineas[i])):
            parrafo.append(lineas[i].strip())
            i += 1
        flujo.append(Paragraph(inline(" ".join(parrafo)), est["p"]))

    return flujo


# ---------------------------------------------------------------------------
#  Documento
# ---------------------------------------------------------------------------
def pie(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(LINEA)
    canvas.setLineWidth(0.5)
    canvas.line(1.7 * cm, 1.35 * cm, A4[0] - 1.7 * cm, 1.35 * cm)
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(GRIS)
    canvas.drawString(1.7 * cm, 1.0 * cm, "Food Store · BD II · TP N.º 8 · 2026-11-01")
    canvas.drawRightString(A4[0] - 1.7 * cm, 1.0 * cm, "Página %d" % doc.page)
    canvas.restoreState()


def main():
    if not ORIGEN.exists():
        sys.exit("No existe %s" % ORIGEN)

    est = estilos()
    md = ORIGEN.read_text(encoding="utf-8")
    flujo = parsear(md, est)

    doc = BaseDocTemplate(
        str(DESTINO), pagesize=A4,
        leftMargin=1.7 * cm, rightMargin=1.7 * cm,
        topMargin=1.5 * cm, bottomMargin=1.7 * cm,
        title="TP 8 - Food Store en la feria", author="Saleme Ismael",
        subject="Base de Datos II - UTN TUP",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="normal")
    doc.addPageTemplates([PageTemplate(id="todas", frames=[frame], onPage=pie)])
    doc.build(flujo)

    print("PDF generado: %s" % DESTINO)
    print("Paginas: %d" % doc.page)


if __name__ == "__main__":
    main()
