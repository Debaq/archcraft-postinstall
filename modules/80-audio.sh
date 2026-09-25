# Repara el audio con diag-audio.sh (paquetes, firmware, PipeWire, salida por parlantes) y deja
# el diagnóstico en ~/audio-<hostname>.txt. Sin tono de prueba: puede correr por SSH.

"$ROOT/diag-audio.sh" --sin-prueba || warn "diag-audio.sh falló: revisa ~/audio-*.txt"
