# Informe de resultados — completar con evidencia real

Estado inicial: **PENDIENTE DE EJECUCIÓN EN VIRTUALBOX**. Los valores en blanco no son aprobaciones. No se han medido carga, disponibilidad ni failover en los equipos del estudiante.

## Equipo y entorno

- Integrantes / matrícula: pendiente.
- Fecha y zona horaria: pendiente (evidencias de scripts en UTC).
- Ubuntu / VirtualBox / Docker / Compose: pendiente.
- CPU/RAM/disco del anfitrión y recursos asignados a VM: pendiente.
- Equipo cliente, herramienta/versión, red Wi-Fi/Ethernet/VPN: pendiente.
- IP/puerto del servicio; commit probado; digests: pendiente.

## Resumen medido

| Ensayo | Concurrencia / duración | RPS | p50 / p95 / p99 (ms) | Éxito / fallos / no-2xx | CPU / RAM máxima | Evidencia | Resultado |
|---|---|---|---|---|---|---|---|
| Baseline funcional | — | — | — | — | — | pendiente | pendiente |
| Smoke | 5 / 30 s propuestos | — | — | — | — | pendiente | pendiente |
| Carga | 20 / 10 min propuestos | — | — | — | — | pendiente | pendiente |
| Estrés | niveles progresivos | — | — | — | — | pendiente | pendiente |
| Spike | 5 → 300 → 5 propuesto | — | — | — | — | pendiente | pendiente |
| Soak | 20 / 2 h propuestos | — | — | — | — | pendiente | pendiente |
| Caché / sin caché | comparación | — | — | — | — | pendiente | pendiente |

## Registro de cada fallo

Copiar esta ficha para cada escenario de los puntos 3–5:

- Hipótesis y umbral acordado:
- Servicio y rol real antes del fallo:
- Carga y ruta exacta (¿SQL sin caché? ¿reseñas MongoDB?):
- Hora de inyección, detección, primera recuperación y recuperación estable:
- MTTD / MTTR / interrupción observada y resolución de muestreo:
- Pérdida de quorum esperada o no; elecciones; cambio de VIP/master/backend:
- Disponibilidad por solicitudes y disponibilidad muestreada (distinguir):
- p95/p99, presupuesto de error y ventana:
- Datos escritos antes/después y evidencia de persistencia:
- Estado Nagios, alerta omitida/falsa y logs relacionados:
- Recuperación aplicada y estado final de los tres miembros:
- Conclusión: hipótesis confirmada/rechazada/no ejecutada; causas y próximos pasos:

## Cobertura de la entrega

| Punto | Evidencia requerida | Estado |
|---|---|---|
| 1 | Salud, headers, consistency SQL, reseña MongoDB, caché | Pendiente |
| 2 | Reportes crudos de carga/estrés/spike/soak y recursos | Pendiente |
| 3 | Matriz de fallos con RTO, quorum, VIP, Redis/Mongo primary | Pendiente |
| 4 | Hipótesis, Monkey, red, recurso, compuesto y recuperación; exclusiones explícitas | Pendiente |
| 5 | Línea temporal Nagios/logs/sonda, MTTD/MTTR y error budget | Pendiente |

## Conclusión a redactar después de medir

Explicar qué fallos de contenedor se toleraron, cuánto tardó la recuperación, primer cuello de botella, cambios necesarios y límites de una sola VM. No escribir que hay alta disponibilidad de host ni que se ejecutó en AWS. Anotar los ensayos no realizados (por ejemplo reloj/disco) y su justificación.
