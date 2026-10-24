# Informe de resultados — laboratorio de sistema distribuido

**Estado:** infraestructura y primera prueba de carga verificadas el **24 de octubre de 2026** con salidas de la VM compartidas por el estudiante. **Las pruebas remotas, de fallos y Chaos Engineering siguen pendientes** hasta contar con registros de su ejecución. No se inventan resultados.

## Equipo y entorno

- Servidor: Ubuntu en una VM de VirtualBox; Docker Compose, proyecto `distributed-ha-lab`.
- Fecha observada de prueba: 2026-10-24. Las rutas generadas por los scripts y sus marcas temporales utilizan UTC.
- IP LAN de la VM durante las pruebas: `192.168.1.88:80`; vía adaptador puente Wi-Fi. También se observó `192.168.1.87` en otro adaptador de la misma subred; conviene mantener solo uno para evitar enrutamiento ambiguo.
- Peticiones de verificación satisfactorias en `localhost` y `192.168.1.88`. **Esto no sustituye probar desde el equipo del compañero.**
- Máquina cliente externa, integrantes/matrícula, CPU/RAM/disco, versiones exactas de Docker/Compose, commit efectivamente desplegado y digests: **pendientes de registrar**.
- La prueba de carga inicial se lanzó desde la **propia VM**, no desde un cliente externo.
- Nagios: figura `Exited (255)` en la última salida archivada; posteriormente el estudiante informa que lo reinició y funciona, **pendiente de incorporar una nueva captura `docker compose ps -a nagios` y evidencia de interfaz**.

## Salud y balanceo observados

La salida de `bash scripts/verify.sh | tee results/baseline.txt` mostró:

- **Galera:** `galera1`, `galera2`, `galera3` con `wsrep_local_state_comment=Synced`, `wsrep_cluster_status=Primary`, `wsrep_cluster_size=3` y `wsrep_ready=ON`.
- **MongoDB:** `mongo2` PRIMARY; `mongo1` y `mongo3` SECONDARY; salud 1 para los tres.
- **Redis Sentinel:** `CKQUORUM cachemaster` satisfactorio en los tres Sentinel; en ese instante los tres reportaron master `172.28.0.23:6379`.
- **API profunda:** `{"sql":true,"mongo":true,"cache":true}`.
- **Balanceo de presentación y aplicación:** las cabeceras `x-request-trace` mostraron `webnode1/2/3` y `app1/2/3` durante la verificación; respuestas HTTP 200.
- **Caché:** se observó al menos un `cache miss` que consultó Galera vía proxy y posteriores `cache hit`.
- **Keepalived:** después de recrear solamente los cuatro contenedores, figuraban `Up` durante aproximadamente 29 minutos; aún falta ensayar el desplazamiento de VIP tras fallo del balanceador.
- **Nagios:** se observaron alertas históricas CRITICAL/OK en logs, pero no se ha cuantificado aún MTTD/MTTR ni confirmado su funcionamiento actual con nueva evidencia.

Evidencias **locales a recopilar y versionar sin secretos**: `results/baseline.txt`, capturas de cabeceras/estado, `results/images.txt`, `results/image-digests.txt`, archivos de pruebas de carga y muestras de recursos.

## Primera prueba medida: Smoke / ApacheBench

Ejecutada en el servidor VM con `bash tests/load.sh "http://192.168.1.88" 5 30` contra `/api/products/cheapest`.

| Métrica | Resultado observado |
|---|---:|
| Fecha | 2026-10-24 |
| Concurrencia | 5 |
| Duración | 30.001 s |
| Peticiones completadas | 9107 |
| Fallidas según ApacheBench | 0 |
| Solicitudes por segundo | 303.56 |
| Tiempo medio por petición | 16.471 ms |
| Latencia p50 | 14 ms |
| Latencia p95 | 34 ms |
| Latencia p99 | 55 ms |
| Máxima | 136 ms |
| Ruta de evidencia en la VM | `results/ab-20261024T153524Z-c5/` |

**Interpretación limitada:** ApacheBench contabilizó cero peticiones fallidas en este ensayo. No se aportó por separado conteo de respuestas no-2xx ni comprobación del contenido de cada respuesta. Estos resultados no representan el rendimiento desde otra computadora de la LAN.

## Resumen de ensayos

| Ensayo | Concurrencia / duración | RPS | p50 / p95 / p99 (ms) | Éxito / fallos / no-2xx | CPU / RAM máxima | Evidencia | Estado |
|---|---|---:|---|---|---|---|---|
| Baseline funcional | Verificación de servicios | — | — | API 200; subsistemas según arriba | Pendiente | `results/baseline.txt` (VM) | Comprobado |
| Smoke local | 5 / 30 s | 303.56 | 14 / 34 / 55 | 9107 completas / 0 fallidas por ab / no-2xx no informado | Pendiente | `results/ab-20261024T153524Z-c5/` (VM) | Medido |
| Funcional remoto | Equipo externo | — | — | — | — | Pendiente | No ejecutado / no aportado |
| Carga | 20 / 600 s | — | — | — | — | Pendiente | No ejecutado |
| Estrés | 10, 25, 50, 100 / 60 s cada nivel | — | — | — | — | Pendiente | No ejecutado |
| Spike | 5 → nivel acordado → 5 | — | — | — | — | Pendiente | No ejecutado |
| Soak | 20 / 7200 s propuestos | — | — | — | — | Pendiente | No ejecutado |
| Caché / sin caché | 20 / 120 s cada corrida | — | — | — | — | Pendiente | No ejecutado |
| Failover web/API/LB/SQL/Redis/Mongo | Un fallo por escenario | — | — | — | — | Pendiente | No ejecutado |
| Chaos Monkey, red, recursos | Escenarios controlados | — | — | — | — | Pendiente | No ejecutado |
| Nagios / alertas / recuperación | Capturas, logs, CSV | — | — | — | — | Pendiente | No cuantificado |

## Registro de cada fallo

Copiar esta ficha por escenario y añadir ruta de evidencia:

- Hipótesis y umbral acordado:
- Servicio y rol real antes del fallo:
- Carga y ruta exacta (`?nocache=1` para SQL; reseñas para MongoDB):
- Hora UTC de inyección, detección, recuperación inicial y estable:
- MTTD / MTTR / duración observada / resolución de muestreo:
- Cambio de VIP/master/backend y quórum:
- Disponibilidad por solicitud vs disponibilidad muestreada:
- p95/p99 y presupuesto de error con ventana:
- Datos escritos antes/después y evidencia de persistencia:
- Alertas Nagios y logs correspondientes:
- Recuperación aplicada y estado final:
- Conclusión: confirmada, rechazada o no ejecutada:

## Cobertura de la entrega

| Punto | Evidencia requerida | Estado |
|---|---|---|
| 1 | Salud, headers, consistencia SQL, reseña MongoDB, caché | Salud/headers/caché observados; consistencia y reseña específica pendientes |
| 2 | Carga remota/estrés/spike/soak con recursos | Solo smoke local medido |
| 3 | Failover de web/API/LB/Galera/proxy/Redis/Mongo y continuidad | Pendiente |
| 4 | Chaos Monkey, red, recursos y límites | Pendiente |
| 5 | Nagios, MTTD/MTTR, alertas y presupuesto de error | Pendiente |

## Ejecución y recolección

Seguir `docs/PRUEBAS.md` **por etapas**, no todos los fallos a la vez. Confirmar un baseline sano antes y después de cada ensayo. Guardar `results/` con salidas reales, excluir contraseñas y secretos. Enviar a GitHub solamente los resultados inspeccionados. No utilizar `docker compose down -v`.

## Conclusión provisional

La VM ha demostrado funcionamiento de clústeres Galera y MongoDB, quórum Redis Sentinel, balanceo entre tres web/API y una primera carga local de 9107 peticiones sin fallos reportados por ApacheBench. **No se ha demostrado aún tolerancia a caída de un balanceador, HA de host, disponibilidad externa sostenida o Chaos Engineering**. Una sola VM y el contenedor de entrada constituyen puntos únicos de fallo; no se afirma despliegue en AWS ni disponibilidad de producción.
