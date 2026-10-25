# Auditoría de los requisitos pendientes — TEST-PLAN puntos 1 al 5

### Prueba spike preliminar añadida: 5→20→5

Pico controlado de **5→20→5** con `ab` en fases de 15 s, acceso cacheado al catálogo. **Fase 1:** 3000 completas, 0 fallidas, 199.74 req/s, p95=59 ms, p99=116 ms. **Fase 2:** 6795 completas, 0 fallidas, 452.79 req/s, p95=93 ms, p99=145 ms. **Fase 3:** 4557 completas, 0 fallidas, 303.74 req/s, p95=28 ms, p99=37 ms. Total **14 352 completas y 0 fallidas según ab**. Salud profunda final **HTTP 200**. Capturas de CPU/RAM generadas pero aún **no interpretadas**. **NO sustituye** el escenario exigido de **5→300→5**; por episodios WSREP `non-Primary`, no se debe escalar sin guardas y diagnóstico. Evidencias en `results/spike/` en VM; revisar códigos HTTP no-2xx en archivos completos.

### Capturas de CPU/RAM interpretadas para spike 5→20→5

Analizadas instantáneas `docker stats` de seis contenedores en las tres fases: en 20 usuarios, `web1` 11.81% CPU/5.621 MiB, `app1` 26.25% CPU/61.88 MiB, `galera1` 0.18%/252.5 MiB, `galera2` 0.69%/185 MiB, `galera3` 0.58%/129.7 MiB, `redis1` 6.35%/4.871 MiB. Sin elevación manifiesta de RAM en las tres muestras. Las métricas son **puntuales**, no picos o medias del experimento ni prueba de soak. Ninguna línea `Non-2xx responses` en los reportes mostrados y `Failed requests: 0` en las tres fases. Salud final `/api/health/deep` HTTP 200. **Punto 2 permanece parcialmente pendiente:** spike requerido 5→300→5, soak de horas y recursos de todo el stack. No arriesgar Galera hasta resolver intermitencia WSREP.

### Latencia de red app1 ejecutada, disponibilidad 84.21% y HTTP 503 pendiente de diagnóstico

El ensayo de red de `app1` **sí inyectó** `tc netem delay 200ms 50ms` en `eth1` durante 12 s y reportó retirada exitosa; sonda: **32/38** muestras exitosas (**84.21%**), **6 fallos**. El endpoint `GET /api/health/deep` terminó en **HTTP 503** `No server is available to handle this request`. **Prueba ejecutada pero no aprobada** según hipótesis de disponibilidad 99%; no afirmar resiliencia bajo este fallo. Pendiente identificar capa responsable y confirmar recuperación; prohibido escalar a más inyecciones o carga antes de diagnosticar la ruta HAProxy → API → datos. Correlación temporal no prueba causa única; Galera ya tuvo incidentes no-Primary espontáneos.

### Recuperación posterior a netem app1 verificada; causa de 503 pendiente

**Diagnóstico posterior a HTTP 503:** netem removida (`app1/eth1 qdisc noqueue`); tres API directas `/health` y `/health/deep` **HTTP 200**, cada nodo Galera `Synced/Primary/wsrep_ready ON/size 3`, 3/3 solicitudes finales a `/api/health/deep` **HTTP 200**. Proxy SQL y HAProxy application estuvieron `Up`. La ruta se recuperó **sin reinicio de bases ni intervención en redes**. **Sigue sin aprobarse la disponibilidad bajo latencia**: 32/38 muestras durante ensayo (84.21 %), con HTTP 503 al término inmediato. Pendiente correlación de logs a partir de **03:55:15 UTC** para determinar origen exacto del fallo y tiempo real de recuperación; no repetir netem todavía.

## Corte de resultados del 25-10-2026: avances y límites

**Este corte es más reciente que las secciones históricas inferiores.** Implementadas las mejoras Mongo Replica Set, Redis Sentinel y proxy SQL con tres miembros Galera. **Punto 1:** verificación funcional, rondas y consistencia evidenciadas. **Punto 2:** carga de 600 s (302 663 peticiones, 0 errores reportados por ab), estrés, comparación con/sin caché y capacidad directa a `web1` (**100 000; 6374.08 req/s; p95 2 ms; 0 fallos según ab**) y `app1` sin caché (**15 233; 761.64 req/s; p95 13 ms; 0 fallos según ab**). **Pendientes:** spike 5→300→5, soak de horas y métricas CPU/RAM durante pruebas bajo carga; no equiparar las rutas directas web/API.

**Punto 3:** probados failover de ambos HAProxy/Keepalived, proxy SQL, Redis Sentinel (cambio redis3→redis1 y posterior 2 réplicas), Mongo replica set (mongo1→mongo2, 97/97 lecturas), además de web/app. **Galera permanece sin prueba de parada voluntaria** por episodios repetidos de `non-Primary` temporales observados espontáneamente en Galera2/Galera3. Hubo interrupciones en varias sondas HAProxy/SQL/Redis; no afirmar SLO universal.

**Punto 4:** Chaos Monkey `DRY_RUN` 38/38; reales con `web1` **42/43 (97.67%)**, `app1` **45/45 (100%)**, recuperaciones comprobadas. Quedan red/recursos/fallos compuestos y casos no seguros sujetos a evaluación. **Punto 5:** Nagios recuperado sobre mismo contenedor tras `Exited (255)`; estado exportado: **24/24 hosts UP y 30/30 servicios OK**, historial de alertas y tiempos de un ensayo web1 disponibles; envío de notificaciones externas y promedios múltiples de MTTD/MTTR no verificados. `GET /api/health/deep` HTTP 200 al finalizar las últimas pruebas.

**Próximo enfoque seguro:** carga pico preliminar controlada con concurrencia baja a moderada y métricas de recursos, sin repetir paradas de bases de datos hasta investigar WSREP; mantener sin ejecutar escenarios de alto riesgo y documentarlos con honestidad. Ver `docs/RESULTADOS.md` para evidencias y limitaciones exactas.


**Revisión:** 24 de octubre de 2026. **Fuente del alcance:** enunciado docente proporcionado por el equipo: *mejorar MongoDB 2.1, Redis 2.2/2.3 y todo Galera ToDo 3*; **ejecutar los puntos 1–5 de `resilience-lab/TEST-PLAN.md`**. Estos cinco puntos son **parte del encargo**, no opcionales. La presencia de scripts no equivale a haberlos ejecutado.

## Estado actualizado al 25 de octubre de 2026: recuperación y carga sostenida

**Actualización posterior a las observaciones históricas del 24-10-2026.** Tras expandir la partición raíz de Ubuntu a **70 GB (45 GB disponibles, 34% ocupado)** y recuperar tres miembros Galera, sus monitores, Keepalived y API, el operador ejecutó `bash scripts/verify.sh` con **código 0**. `/api/health/deep` respondió `{"sql":true,"mongo":true,"cache":true}`. El archivo de verificación está en `results/cierre/verificacion-posrecuperacion.txt` (VM).

**Punto 2 — carga sostenida: completada localmente.** Se ejecutó ApacheBench en la VM sobre `http://127.0.0.1/api/products/cheapest`, **20 conexiones**, **600.002 segundos**, **302 663 solicitudes completadas**, **0 fallidas informadas por ab**, **504.44 req/s**, **p50=33 ms, p95=87 ms y p99=134 ms**, máximo **2871 ms**. Evidencia: `results/carga/carga-real-20usuarios-600s.txt`, todavía en VM. No hubo desglose independiente de todos los códigos HTTP, ni CPU/RAM simultánea. Se usó la ruta cacheada con Redis; no equivale a prueba remota desde Windows.

**Punto 3 — failover app1: ejecutado, no aprobado sin reservas.** La sonda de un ensayo anterior capturó 64 de 80 muestras exitosas (80%), con 16 errores; la API recuperó salud después. Faltan análisis de los 16 errores y otros failovers.

**Aún pendientes de los puntos 1-5:** estrés escalonado, spike, soak de horas, comparación de caché / sin caché, capacidad por capa y recursos en carga; validación funcional desde un cliente externo; failover LB/SQL/Redis/Mongo/Galera con evidencias; Chaos Monkey y fallos de red/recursos que puedan ensayarse sin poner en riesgo datos; publicación de logs sin secretos y análisis consolidado Nagios de múltiples fallos. Los planes de varias horas o con particiones de datos deben ejecutarse únicamente en condiciones controladas, no declararse hechos por existir scripts.

**Estrés escalonado ejecutado:** c25 (30 655 completas, p95 117 ms) y c50 (28 854 completas, p95 235 ms), ambos con 0 fallidas reportadas por ab. El objetivo p95<200 ms se rebasó en c50; se justificó detener el escalamiento antes de c100. **Siguiente prioridad:** failover controlado de un HAProxy con sonda simultánea y verificación posterior, y primer Chaos Monkey seguro sobre nodos web. El resultado de la carga sostenida ya fue registrado en `docs/RESULTADOS.md`; no repetirla.

### Avance adicional: comparación de caché completada (25-10-2026 UTC)

La comparación local requerida del punto 2 entre ruta cacheada y `?nocache=1` se ejecutó con ApacheBench (**5 conexiones**, 30 s por escenario). **Con caché:** 10 319 completas, 0 fallidas por ab, 343.92 req/s, p95 27 ms. **Sin caché:** 8 659 completas, 0 fallidas por ab, 288.55 req/s, p95 31 ms. El throughput con caché fue **aprox. 19.2% mayor** y la latencia media **aprox. 16.1% menor**; el health posterior de SQL/Mongo/Redis devolvió todos `true`. Evidencia en la VM: `results/cache/con-cache.txt` y `results/cache/sin-cache.txt` (no subida).

El punto 2 sigue **parcial**: spike, soak de horas, capacidad por capa, CPU/RAM durante pruebas y pruebas desde cliente externo continúan pendientes. No repetir los ensayos de 30 s solo para completar la evidencia actual. El punto 3 está parcial, punto 4 sin ejecutar y punto 5 parcialmente probado con Nagios. Los datos de caché corresponden a omitir la caché mediante parámetro; no constituyen inyección de fallo de Redis.

## A. Infraestructura y archivos de entrega — listos

- [x] HAProxy master/backup + Keepalived de presentación, VIP interna (archivo de configuración y verificación de propietario único).
- [x] Tres nodos web (Nginx), tres API Node.js.
- [x] HAProxy master/backup + Keepalived de aplicación.
- [x] Tres Galera Synced, con replicación de escritura y lectura causal entre los tres nodos comprobada.
- [x] MongoDB replica set de tres miembros (1 PRIMARY/2 SECONDARY observado) y reseña escrita/leída mediante API.
- [x] Redis/Sentinel de tres miembros, quórum Sentinel y caché observados. La elección de **caché desechable** sin AOF/RDB, con TTL, está documentada como decisión de ToDo 2.3; no se requiere fingir que los datos de caché son duraderos.
- [x] ToDo punto 3: API no depende directamente de galera1; dos proxies SQL con chequeos wsrep; política de lectura/escritura documentada; límites de pools definidos en código.
- [x] Diagrama `docs/arquitectura.jpg`, Markdown, Compose, Dockerfiles/configuraciones en `main`.
- [x] Capturas originales de Nagios publicadas en [evidencias](evidencias/README.md).

**IMPORTANTE:** que un componente esté implementado no demuestra su **alta disponibilidad en un fallo real**. Todo el laboratorio corre en **una VM** y no ofrece HA del host. El enunciado permite explícitamente contenedores o VMs; no obliga a desplegar Kubernetes ni OpenTelemetry del ToDo punto 5, pues las mejoras de ToDo exigidas son **2.1–2.3 y todo el 3**. La **observabilidad del punto 5 de TEST-PLAN sí es obligatoria**.

## B. Estado de las pruebas exigidas

| Punto | Ensayo / resultado | Situación |
|---|---|---|
| **1. Baseline** | Salud profunda API 200, tres Galera Primary/Synced, Mongo PRIMARY/SECONDARY, Sentinel CKQUORUM, rutas web/API, SQL replicación, Mongo reseñas, cache miss/hit, VIP único por capa | **Hecho en VM**; falta consolidar logs/capturas sin secretos |
| **2. Rendimiento** | Smoke c5/30s (9,107 peticiones), carga corta c20/60s (24,692) y sostenida local c20/600.002s (**302,663 peticiones, 0 fallos de ab, p95=87 ms**) | **Carga local de 10 minutos terminada**; no sustituye carga remota |

| **2. Rendimiento** | Estrés, spike, soak de horas, caché vs nocache, capacidad por capa, RAM/CPU simultánea y medición externa | **Pendiente**; load 10 min local ya documentada |
| **3. Failover** | `web1` parado y recuperado; un ensayo tuvo sonda 144/145 muestras correctas | **Hecho para web1** |
| **3. Failover** | `app1` (64/80 muestras exitosas), presentación LB master, aplicación LB master, `galera1/2`, proxy SQL, master Redis y PRIMARY Mongo | **app1 ejecutado con 16 errores; demás pendientes** |
| **3. Failover** | Escenarios negativos/reducción de capacidad (dos web, ambos LB, caída entry, Redis entero), si se evalúa el TEST-PLAN literal | **Pendiente; planear ventana y recuperación** |
| **4. Chaos** | Chaos Monkey aleatorio y comparación de disponibilidad, empezando en grupo `web` y después `app` | **No ejecutado; implementado como código** |
| **4. Chaos** | Latencia/jitter, pérdida, ancho de banda, fallos de recursos, compuestos; partición/quórum solo con precauciones | **No ejecutados**. Escenarios de reloj/disco lleno deben declararse no aplicables a VM única salvo laboratorio aislado |
| **5. Observabilidad** | Nagios accesible desde Windows por túnel SSH; tres PNG muestran 24 UP → 23 UP / 1 DOWN → 24 UP y 30 servicios OK | **Evidencia real incluida** |
| **5. Observabilidad** | Unir capturas y eventos al log de inyección, medir MTTD/MTTR, disponibilidad e impacto, contar alertas no detectadas y falsas | **Cronología de un ensayo web1 ya correlacionada:** Nagios HOST DOWN SOFT +6 s, SERVICE CRITICAL HARD +14 s, HOST DOWN HARD +48 s, recuperación OK/UP +134 s; faltan logs brutos publicados y medias de varias ejecuciones. Las capturas siguen mostrando solo servicios OK |

## C. Orden razonable para completar con el menor riesgo

**Antes de cualquier prueba:** el último dato de capacidad mostró un disco de 25 GB al 95 % (aprox. 1.4 GB libres). **Revisar primero**:

```bash
cd ~/distributedsystems
df -h /
df -i /
docker system df
docker compose ps
curl --noproxy '*' -fsS --max-time 10 http://localhost/api/health/deep
```

Si hay problemas de capacidad o salud, **no cargar ni inyectar fallos**. No ejecutar `docker compose down -v`, no reconstruir Galera/Mongo, no limpiar volúmenes ni lanzar `first-start.sh` con datos existentes. Tampoco hacer `docker system prune --volumes`.

**Fase 1: pruebas con bajo riesgo.** Guardar estado actual, recursos de CPU/RAM y capturas del diagrama y aplicación; ejecutar prueba desde Windows en una herramienta como JMeter con `tests/catalogo.jmx`: smoke 5 usuarios / 30 s, luego load 20 usuarios / 600 s solo si la VM tiene margen de CPU/RAM/disco. Comprobar HTTP 200, percentiles y tasa de errores. Comparar después caché vs `?nocache=1`. La referencia está en [PRUEBAS.md §2](PRUEBAS.md#2-rendimiento-desde-la-computadora-del-compañero). Registrar si un ensayo se acortó por recursos.

**Fase 2: failover sencillo con sonda independiente.** Un caso por vez con baseline antes y verificación después: `app1`, ambos HAProxy master de presentación y aplicación y un proxy SQL. Comparar la IP propietaria de la VIP y los headers. **No ejecutar varios fallos simultáneos.** `scripts/fault.sh` tiene recuperación al terminar, pero los reinicios previos pudieron volver a lanzar `mongo-init` y `catalog-init`; supervisar el log. [PRUEBAS.md §3](PRUEBAS.md#3-alta-disponibilidad-y-failover).

**Fase 3: Redis/Mongo/Galera.** Solo cuando haya espacio, un backup apropiado y quorum comprobado. Identificar el Redis master actual vía Sentinel y Mongo PRIMARY actual vía rs.status() (no asumir índice fijo). Probar conservación de catálogo/reseñas y restauración de tres miembros. Posponer si existe cualquier duda sobre recuperación. [PRUEBAS.md §3](PRUEBAS.md#3-alta-disponibilidad-y-failover).

**Fase 4: Chaos Monkey de contenedores.** `resilience-lab/chaosmonkey/chaosmonkey.py` y [PRUEBAS.md §4](PRUEBAS.md#4-chaos-engineering) están disponibles, **pero no hay evidencia de ejecución**. Empezar con *dry run*, grupo `web`, `MAX_CONCURRENT=1`, observar estado y captura de cliente; después un ensayo real controlado si la VM se mantiene sana. Su Compose usa socket Docker con privilegios, por lo que solo correr en Ubuntu local de confianza. Evitar `GROUP=any` y particiones de Galera por defecto.

**Fase 5: monitoreo/resultados.** Guardar `results/` local, revisar que no contiene credenciales y publicar evidencias seleccionadas. Correlacionar UTC de inyección, primera alerta, restauración y primeras respuestas estables. Calcular MTTD y MTTR solo con timestamps suficientes, distinguir disponibilidad muestreada de éxito por solicitud y reportar lo no ejecutado explícitamente. [PRUEBAS.md §5](PRUEBAS.md#5-observabilidad-y-alertas).

**Si el profesor interpreta «puntos 1 a 5» literalmente como *todos* los casos del TEST-PLAN**, faltan también los escenarios de estrés extremo, soak largo y fallos de red/recursos/compuestos. No deben declararse finalizados mediante un solo experimento. Se recomienda priorizar el conjunto seguro, informar al profesor las limitaciones de VM y documentar por separado el alcance efectivamente cubierto.

### Inventario recuperado en Ubuntu el 24-10-2026 (aún no revisado íntegramente)

El operador ejecutó `find results -maxdepth 3 -type f | sort` en su VM y confirmó que **los archivos siguientes existen localmente** pese al cambio anterior de IP:

- Rendimiento: `results/ab-20261024T153524Z-c5/{ab.txt,health.json,percentiles.csv,run.txt,times.tsv}`.
- Baseline: `results/baseline.txt`, `results/baseline-servidor.txt`, `results/baseline-repeticion.txt`.
- Inyección `web1`: `results/fault-20261024T155743Z-web1.log`, `results/fault-20261024T221422Z-web1.log`, `results/fault-20261024T223842Z-web1.log`.
- Sondas: `results/sonda-fallo-web1.csv`, **`results/sonda-fallo-app1.csv`**.
- Nagios: `results/nagios-antes-recreacion.log`, `results/nagios-historial-antes.log`.
- Verificación posterior: `results/verification-after-web1.txt`, `results/verificacion-web1-nueva.txt`, `results/verificacion-web1-final.txt`.

**Importante:** esta es una confirmación de presencia por nombre, **no una auditoría del contenido**. En particular, existe una sonda de `app1`, **pero no se encontró ningún `fault-*-app1.log`**: no se puede declarar una inyección de fallo de API sin otra evidencia. Tampoco aparecen todavía en este inventario logs de CPU/RAM bajo carga ni resultados de Chaos Monkey. Los registros históricos de Nagios guardados antes de recrearlo no necesariamente incluyen el evento posterior de caída de `web1` cerca de las 22:38 UTC; revisar el log actual y/o los archivos archivados del contenedor. El disco continúa en **95 % de uso y 1.3 GB libres**; no lanzar cargas prolongadas ni construir nuevas imágenes antes de resolverlo.

**Acción próxima sin alterar servicios:** obtener un resumen de los dos CSV de sonda, de las marcas UTC de los `fault-web1.log`, de los percentiles AB y de alertas Nagios actuales; si se publican los archivos, inspeccionar para eliminar contraseñas o datos personales y dejar claro que son evidencias previas al cambio de IP.

### Correlación recuperada después del inventario (24-10-2026)

Al analizar salidas de `fault-20261024T223842Z-web1.log` y del log activo de Nagios, **ya se confirmó el fallo web1 y se calcularon intervalos observados de una sola ejecución**: inyección 22:38:42Z, DOWN SOFT 22:38:48Z (+6 s), CRITICAL HARD 22:38:56Z (+14 s), DOWN HARD 22:39:30Z (+48 s), recuperación solicitada 22:40:45Z, OK/UP HARD 22:40:56Z (+134 s desde la inyección y +11 s tras la solicitud de recuperación). [Detalle y límites](RESULTADOS.md#evidencia-correlacionada-de-nagios-y-fallo-real-de-web1-24-10-2026).

El CSV `sonda-fallo-web1.csv` quedó ratificado con **144/145 = 99.31 % de muestras correctas**, con `TimeoutError` a las 15:57:51Z durante otro ensayo. Los datos de ApacheBench siguen siendo **9,107 solicitudes, 0 fallos, 303.56 req/s y p95=34 ms**. **La sonda de app1 no está evaluada**: un valor vacío o ausente en `ok` interrumpió el resumen y no consta el log de inyección. No se debe marcar failover de API.

**Queda pendiente:** obtener y revisar los archivos brutos (en VM, fuera de GitHub por `.gitignore`) y añadir un registro de recursos bajo carga; realizar otras pruebas de failover/Chaos, y promediar varios ensayos si se usa el término `MTTD/MTTR` como *mean*.

### Sonda de aplicación `app1` revisada (24-10-2026)

La salida de un nuevo análisis del CSV local informa **90 filas: 89 correctas, 0 fallidas, 1 incompleta**. Las primeras trazas HTTP 200 muestran `app1` y `app2`. Se informó **100 % de disponibilidad entre los registros válidos**, sin clasificar la fila incompleta. **Esto no demuestra que `app1` haya sufrido una caída controlada**; no se localizó `fault-*-app1.log` en el inventario de resultados. Para cerrar el ensayo: inspeccionar la fila incompleta y recuperar evidencia de una inyección real de fallo más la verificación posterior. No repetir sin necesidad antes de evaluar salud/disco (95 % de ocupación).

### Sonda de las tres API: fila vacía y distribución observada (24-10-2026)

Confirmado en el CSV local: 90 filas leídas; **89 válidas (`ok=True`)**, ninguna con `ok=False`, y **una fila final vacía (número de línea 91)**. Las trazas prueban distribución entre las tres API: `app1` 32, `app2` 44, `app3` 13. No es evidencia de caída/reinicio de `app1`, pues aún no se encontró su registro de inyección. Próximo paso seguro: inspeccionar/limpiar exclusivamente caché APT y capturar `docker stats` basal antes de pruebas de carga o caos; disco 95 % y 1.3 GB libres.

## D. Checklist de publicación final

- [x] Código/IaC, arquitectura JPG y documentación base en `main`.
- [x] Capturas Nagios inicial, host DOWN y recuperación.
- [ ] Logs de rendimiento y recursos (local y, de ser posible, desde Windows).
- [ ] Evidencias de failover por componente y verificación posterior.
- [ ] Ejecución y resultados de Chaos Monkey; escenarios no ejecutados declarados.
- [x] Cronología Nagios y latencias de detección y recuperación **de un ensayo web1** correlacionadas con `fault.sh` (ver `RESULTADOS.md`).
- [ ] Publicar registros Nagios/fallo originales **saneados**; si se requieren medias MTTD/MTTR, repetir observaciones controladas y calcular promedios.
- [ ] Datos académicos de equipo, materia y fecha, si son requeridos por la portada.

Véase [RESULTADOS.md](RESULTADOS.md) para datos observados y [ENTREGA.md](ENTREGA.md) para estructura de la entrega.
