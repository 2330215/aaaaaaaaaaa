# Efectos provisionales del juego

| Acción | Clip | Recurso compartido |
| --- | --- | --- |
| Salto | `efecto_007.wav` | `player/jump_sound.tres` |
| Disparo y ataque especial | `efecto_023.wav` | `player/shoot_sound.tres` |
| Monedas, manzanas, escudos y moneda especial | `efecto_106.wav` | `level/pickup_sound.tres` |
| Golpes a enemigos y jefes | `efecto_022.wav` | `enemy/hit_sound.tres` |
| Explosiones de enemigos y jefes | `efecto_105.wav` | `enemy/explode_sound.tres` |

Para cambiar una asignación, reemplaza la ruta del clip en el recurso `.tres` correspondiente. Todas las escenas que lo comparten usarán el nuevo audio. Cada recurso tiene un único clip y no aplica variación aleatoria de tono ni volumen. Se conservan las variaciones de tono que ya aplica el personaje al saltar.

Los WAV originales permanecen en sus carpetas. La música sigue usando `level/audio/menu.wav`. Los efectos conservan el bus `SFX` y su control de volumen en ajustes.
