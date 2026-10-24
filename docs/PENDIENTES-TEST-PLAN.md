# Auditoría de los requisitos pendientes — TEST-PLAN puntos 1 al 5

**Revisión:** 24 de octubre de 2026. **Fuente del alcance:** enunciado docente proporcionado por el equipo: *mejorar MongoDB 2.1, Redis 2.2/2.3 y todo Galera ToDo 3*; **ejecutar los puntos 1–5 de `resilience-lab/TEST-PLAN.md`**. Estos cinco puntos son **parte del encargo**, no opcionales. La presencia de scripts no equivale a haberlos ejecutado.

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
| **2. Rendimiento** | Smoke local ApacheBench: 9,107 solicitudes, 0 fallos reportados, 303.56 req/s, 30 s, concurrencia 5 | **Solo smoke**, no sustituye carga externa |
| **2. Rendimiento** | Load 10 min, stress de concurrencia, spike, soak horas, cached vs nocache, capacidad por capa, RAM/CPU y tiempos p50/p95/p99 | **Sin resultados reportados** |
| **3. Failover** | `web1` parado y recuperado; un ensayo tuvo sonda 144/145 muestras correctas | **Hecho para web1** |
| **3. Failover** | `app1`, presentación LB master, aplicación LB master, `galera1/2`, proxy SQL, master Redis y PRIMARY Mongo; verificar continuidad y restablecimiento | **Pendiente** |
| **3. Failover** | Escenarios negativos/reducción de capacidad (dos web, ambos LB, caída entry, Redis entero), si se evalúa el TEST-PLAN literal | **Pendiente; planear ventana y recuperación** |
| **4. Chaos** | Chaos Monkey aleatorio y comparación de disponibilidad, empezando en grupo `web` y después `app` | **No ejecutado; implementado como código** |
| **4. Chaos** | Latencia/jitter, pérdida, ancho de banda, fallos de recursos, compuestos; partición/quórum solo con precauciones | **No ejecutados**. Escenarios de reloj/disco lleno deben declararse no aplicables a VM única salvo laboratorio aislado |
| **5. Observabilidad** | Nagios accesible desde Windows por túnel SSH; tres PNG muestran 24 UP → 23 UP / 1 DOWN → 24 UP y 30 servicios OK | **Evidencia real incluida** |
| **5. Observabilidad** | Unir capturas y eventos al log de inyección, medir MTTD/MTTR, disponibilidad e impacto, contar alertas no detectadas y falsas | **Sin métricas suficientes**. Las capturas NO muestran servicio CRITICAL |

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

## D. Checklist de publicación final

- [x] Código/IaC, arquitectura JPG y documentación base en `main`.
- [x] Capturas Nagios inicial, host DOWN y recuperación.
- [ ] Logs de rendimiento y recursos (local y, de ser posible, desde Windows).
- [ ] Evidencias de failover por componente y verificación posterior.
- [ ] Ejecución y resultados de Chaos Monkey; escenarios no ejecutados declarados.
- [ ] Logs/cronología Nagios y métricas de detección/recuperación.
- [ ] Datos académicos de equipo, materia y fecha, si son requeridos por la portada.

Véase [RESULTADOS.md](RESULTADOS.md) para datos observados y [ENTREGA.md](ENTREGA.md) para estructura de la entrega.
