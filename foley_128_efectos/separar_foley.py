#!/usr/bin/env python3
"""Separa un archivo de efectos de sonido por pausas de bajo volumen.

Instalación: python -m pip install numpy soundfile
Uso: python separar_foley.py foley-preview.ogg
     python separar_foley.py foley-preview.ogg --umbral-db -38 --silencio-ms 110
"""

import argparse
import csv
from pathlib import Path

import numpy as np
import soundfile as sf


def detectar_segmentos(audio, sr, umbral_db, silencio_ms, antes_ms, despues_ms,
                       duracion_min_ms, ventana_ms=5):
    # RMS por ventanas pequeñas: funciona incluso si los silencios no son 100% mudos.
    hop = max(1, round(sr * ventana_ms / 1000))
    n = len(audio) // hop
    if n == 0:
        return []

    bloques = audio[:n * hop].reshape(n, hop, audio.shape[1])
    rms = np.sqrt(np.mean(bloques.astype(np.float64) ** 2, axis=(1, 2)))
    activo = rms > 10 ** (umbral_db / 20)
    if not np.any(activo):
        return []

    # Inicios y finales de las zonas que superan el umbral.
    cambios = np.diff(np.r_[False, activo, False].astype(np.int8))
    comienzos = np.flatnonzero(cambios == 1)
    finales = np.flatnonzero(cambios == -1)  # índice exclusivo

    # Unir trozos de un mismo sonido si su pausa es demasiado corta.
    pausa_frames = max(1, round(silencio_ms * sr / (1000 * hop)))
    grupos = []
    inicio = int(comienzos[0])
    fin = int(finales[0])
    for s, e in zip(comienzos[1:], finales[1:]):
        s, e = int(s), int(e)
        if s - fin < pausa_frames:
            fin = e
        else:
            grupos.append((inicio, fin))
            inicio, fin = s, e
    grupos.append((inicio, fin))

    pad_antes = round(sr * antes_ms / 1000)
    pad_despues = round(sr * despues_ms / 1000)
    resultado = []
    for i, (s, e) in enumerate(grupos):
        inicio_audio = s * hop
        fin_audio = min(len(audio), e * hop)
        if (fin_audio - inicio_audio) / sr * 1000 < duracion_min_ms:
            continue
        ini = max(0, inicio_audio - pad_antes)
        fin = min(len(audio), fin_audio + pad_despues)
        resultado.append([ini, fin, inicio_audio, fin_audio])

    # Evita que los sonidos vecinos compartan parte del siguiente golpe.
    for a, b in zip(resultado, resultado[1:]):
        mitad_pausa = (a[3] + b[2]) // 2
        a[1] = min(a[1], mitad_pausa)
        b[0] = max(b[0], mitad_pausa)

    return [(ini, fin) for ini, fin, _, _ in resultado if fin > ini]


def main():
    parser = argparse.ArgumentParser(
        description="Extrae sonidos individuales de un OGG/WAV/FLAC/MP3 (si libsndfile lo admite)."
    )
    parser.add_argument("archivo", type=Path, help="Archivo de audio de entrada")
    parser.add_argument("--salida", type=Path, default=None, help="Directorio de salida")
    parser.add_argument("--umbral-db", type=float, default=-35,
                        help="Nivel que se considera sonido activo, en dBFS (por defecto -35)")
    parser.add_argument("--silencio-ms", type=float, default=70,
                        help="Pausa mínima para separar dos sonidos (por defecto 70 ms)")
    parser.add_argument("--antes-ms", type=float, default=25,
                        help="Margen de inicio antes del sonido (por defecto 25 ms)")
    parser.add_argument("--despues-ms", type=float, default=220,
                        help="Margen después del sonido, para conservar colas (por defecto 220 ms)")
    parser.add_argument("--duracion-min-ms", type=float, default=15,
                        help="Ignora eventos activos más cortos (por defecto 15 ms)")
    parser.add_argument("--formato", choices=("wav", "ogg"), default="wav",
                        help="Exportar en WAV (recomendado) u OGG")
    args = parser.parse_args()

    if not args.archivo.is_file():
        parser.error(f"No existe el archivo: {args.archivo}")
    if args.silencio_ms <= 0 or args.antes_ms < 0 or args.despues_ms < 0:
        parser.error("Los parámetros de tiempo deben ser válidos y no negativos")

    audio, sr = sf.read(args.archivo, dtype="float32", always_2d=True)
    segmentos = detectar_segmentos(
        audio, sr, args.umbral_db, args.silencio_ms,
        args.antes_ms, args.despues_ms, args.duracion_min_ms,
    )
    salida = args.salida or args.archivo.with_name(args.archivo.stem + "_separado")
    salida.mkdir(parents=True, exist_ok=True)
    ruta_csv = salida / "segmentos.csv"

    with ruta_csv.open("w", encoding="utf-8", newline="") as f:
        csvwriter = csv.writer(f)
        csvwriter.writerow(("archivo", "inicio_seg", "fin_seg", "duracion_seg"))
        for i, (ini, fin) in enumerate(segmentos, start=1):
            nombre = f"efecto_{i:03d}.{args.formato}"
            clip = audio[ini:fin].copy()

            # Fundido de 5 ms: previene clics si una cola queda cortada.
            fade = min(round(sr * 0.005), len(clip) // 2)
            if fade:
                clip[:fade] *= np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
                clip[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)[:, None]

            destino = salida / nombre
            if args.formato == "wav":
                sf.write(destino, clip, sr, subtype="PCM_16")
            else:
                sf.write(destino, clip, sr, format="OGG", subtype="VORBIS")
            csvwriter.writerow((nombre, f"{ini/sr:.3f}", f"{fin/sr:.3f}",
                                f"{(fin-ini)/sr:.3f}"))
    print(f"Archivo: {args.archivo}")
    print(f"Duración: {len(audio)/sr:.2f} s | Frecuencia: {sr} Hz")
    print(f"Detectados y exportados: {len(segmentos)} efectos")
    print(f"Carpeta: {salida.resolve()}")
    print(f"Tiempos originales: {ruta_csv.resolve()}")
    if not segmentos:
        print("No se detectó audio con esos parámetros. Prueba --umbral-db -45")


if __name__ == "__main__":
    main()
