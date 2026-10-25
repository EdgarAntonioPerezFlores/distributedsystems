# Entrega del sistema distribuido — resumen verificable

**Fecha de revisión:** 25 de octubre de 2026 (UTC). **Repositorio y rama:** [EdgarAntonioPerezFlores/distributedsystems · main](https://github.com/EdgarAntonioPerezFlores/distributedsystems/tree/main).

## 1. Entregables solicitados por el profesor

| Entregable | Ruta | Estado |
|---|---|---|
| Diagrama de arquitectura en JPG | [docs/arquitectura.jpg](arquitectura.jpg) | **Incluido** |
| Documentación Markdown | [ARQUITECTURA](ARQUITECTURA.md), [GUIA-UBUNTU](GUIA-UBUNTU.md), [OPERACION](OPERACION.md), [PRUEBAS](PRUEBAS.md), [RESULTADOS](RESULTADOS.md) | **Incluida** |
| Infraestructura como código y configuraciones | [docker-compose.yml](../docker-compose.yml), [haproxy](../haproxy/), [keepalived](../keepalived/), [ha](../ha/), [nagios](../nagios/), [Dockerfiles y aplicación](../application/) | **Incluidos** |
| Evidencia visual complementaria | [Galería de Nagios](evidencias/README.md) | **3 PNG publicados en GitHub** |

### Componentes pedidos y su implementación

| Componente | Implementación |
|---|---|
| Presentación: HAProxy master y backup + Keepalived | Dos HAProxy de presentación, pareja Keepalived y VIP `172.30.0.250`; punto de entrada HTTP independiente |
| Web: tres nodos | `web1`, `web2`, `web3` (Nginx) |
| Aplicación: HAProxy master y backup + Keepalived | Dos HAProxy de aplicación, pareja Keepalived y VIP `172.31.0.250` |
| API: tres nodos | `app1`, `app2`, `app3` (Node.js) |
| SQL: tres Galera | `galera1`, `galera2`, `galera3` y dos proxies de acceso SQL |
| MongoDB | `mongo1`, `mongo2`, `mongo3` en replica set |
| Redis | `redis1`, `redis2`, `redis3` y `sentinel1`, `sentinel2`, `sentinel3` |
| Observabilidad | Nagios Core, registros y scripts de verificación |

**Resultado de auditoría de archivos:** están presentes en la rama `main` el JPG, los tres PNG originales y todos los archivos de configuración citados. La arquitectura usa una **única VM Ubuntu de VirtualBox**: permite probar continuidad frente a fallos de contenedores, **no alta disponibilidad de todo el host físico**.

## 2. Evidencia efectivamente obtenida (no simulada)

**Funcionalidad y replicación (TEST-PLAN 1).** `scripts/verify.sh` finalizó con código 0 en la validación reportada. Los tres nodos Galera mostraron `Synced / Primary / cluster_size=3 / wsrep_ready=ON`, con comprobación de escritura/lectura entre nodos; MongoDB funcionó con 1 PRIMARY y 2 SECONDARY y se comprobó persistencia de reseña; Redis Sentinel confirmó elección de master y consultas de caché. Tras un episodio WSREP, se registraron **6 rondas, 18/18 checks Galera correctos entre 04:07:06 y 04:08:05 UTC**, y salud general HTTP 200. Son observaciones puntuales, no garantía de estabilidad indefinida.

**Rendimiento (TEST-PLAN 2).**
- Smoke local de 30 s y concurrencia 5: **9107 peticiones exitosas, p95 34 ms**.
- Carga sostenida 20 conexiones/600 s: **302 663 completas, 0 fallidas según ApacheBench, 504.44 req/s, p95 87 ms**.
- Estrés con concurrencia 25: **30 655, 510.86 req/s, p95 117 ms**; concurrencia 50: **28 854, 480.79 req/s, p95 235 ms**, excediendo objetivo de p95 < 200 ms.
- Comparación de caché: **343.92 req/s con Redis y 288.55 req/s sin caché** (aprox. +19.2 % según estos ensayos).
- Capacidad directa: Nginx `web1` **100 000 peticiones, 6374.08 req/s, p95 2 ms**; API `app1` sin caché **15 233, 761.64 req/s, p95 13 ms**, sin fallidas según `ab`. Son operaciones diferentes, no comparación directa de eficiencia.
- Pico moderado preliminar **5→20→5**: **3000 + 6795 + 4557 = 14 352 peticiones**, ninguna fallida según `ab`, p95 **59/93/28 ms**, memoria sin aumentos significativos en tres instantáneas; pico CPU observado `app1` **26.25 %**. **No sustituye** spike solicitado **5→300→5** ni soak de horas.

**Alta disponibilidad y failover (TEST-PLAN 3).** Se observaron cambios reales de VIP y recuperación en HAProxy de presentación y aplicación, además del proxy SQL alternativo; las sondas tuvieron, respectivamente, **50/56**, **74/88** y **66/67** respuestas exitosas, con interrupciones transitorias. Sentinel promovió `redis1` tras caída del antiguo master `redis3` (**91/92** respuestas) y MongoDB promovió `mongo2` tras detener `mongo1` (**97/97** lecturas muestreadas), conservando la reseña comprobada. **No se ejecutó parada controlada de nodos Galera** por inestabilidad espontánea previa `NON-PRIMARY` y riesgo de datos/quórum.

**Chaos Engineering (TEST-PLAN 4).** Chaos Monkey en simulación `DRY_RUN` **38/38**; en fallos de contenedores reales: `web1` **42/43 (97.67 %)** y `app1` **45/45 (100 %)**, con restauración automática. El experimento de red real `app1/eth1` aplicó **`tc netem delay 200ms 50ms` durante 12 s** y eliminó la regla; sonda **32/38 (84.21 %)**, seguida inmediatamente de **HTTP 503**. En ese intervalo, **galera2 y galera3** registraron timeouts WSREP y estados `NON-PRIMARY`, aunque no se demostró que la latencia en `app1` los causara. Posteriormente, las tres API respondieron HTTP 200, Galera se comprobó sincronizado y la salud pública fue HTTP 200; el ensayo de disponibilidad bajo latencia **no aprobó** la hipótesis >=99 %.

**Observabilidad (TEST-PLAN 5).** Nagios registró alertas reales de caída/recuperación de `web1`, `app1` y dependencias; para un fallo web1 se documentó primera detección SOFT a **6 s**, servicio HARD a **14 s** y host HARD a **48 s**, con recuperación registrada tras la restitución. Se recuperó el mismo contenedor de Nagios desde `Exited (255)`, sin recrearlo; el estado exportado mostró **24/24 hosts UP y 30/30 servicios OK**, y la interfaz devolvió HTTP 401 por requerir autenticación. Existen **3 capturas PNG** en [la galería](evidencias/README.md). No se ha demostrado envío de alertas externas ni calculado MTTD/MTTR promedio de múltiples experimentos.

**Límites del laboratorio:** infraestructura concentrada en **una sola VM Ubuntu/VirtualBox**, sin tolerancia a caída del host; resultados de carga obtenidos localmente, no desde otra máquina; Galera ha mostrado fallos transitorios WSREP aun sin inyección directa de fallos sobre sus miembros. Evidencias detalladas y archivos locales: [RESULTADOS.md](RESULTADOS.md) y [PENDIENTES-TEST-PLAN.md](PENDIENTES-TEST-PLAN.md).

## 3. Pendientes reales y condiciones de entrega

**Los puntos 1–5 de [TEST-PLAN](../resilience-lab/TEST-PLAN.md) forman parte del encargo docente**; se distingue cuidadosamente cada escenario ejecutado de los pendientes. Aún faltan principalmente: **spike 5→300→5**, **soak de varias horas**, cobertura de capacidad a nivel DB, algunos fallos compuestos/de recursos y red, **failover voluntario de Galera** (pospuesto para no arriesgar datos con inestabilidad WSREP), y promedios de MTTD/MTTR y verificación de alertas externas. Los eventos observados se documentan aunque incumplan metas de disponibilidad.

**Para preparar la entrega sin inyecciones nuevas:** 
1. Completar nombres de integrantes, materia/grupo y fecha de entrega si el profesor lo requiere. No se inventan datos personales.
2. Adjuntar capturas recientes del sistema y de Nagios, y conservar los archivos bajo `results/` en la VM. Los reportes Markdown principales están en GitHub, pero los logs/csv locales no deben darse por subidos automáticamente.
3. Comprobar estado final y espacio. La última lectura de `df -h /` mostró **70 GB totales, 23 GB usados, 44 GB libres (35 % de uso)**; el dato anterior de 95 % ya no representa la situación después de la ampliación.
4. No ejecutar `docker compose down -v`, inicializadores sobre datos existentes, reinicios/bootstrap simultáneos Galera ni pruebas de partición bajo WSREP inestable.

### Estado de cierre comprobado en Ubuntu (25-10-2026 UTC)

`git pull --ff-only origin main` completó el avance hasta **`61cb0cb`**; contenedores de aplicación, balanceo, Galera, MongoDB, Redis, Sentinel y Nagios aparecieron **Up**, las bases de datos `healthy` donde tienen healthchecks, **Nagios Up 40 minutos**, `GET /api/health/deep` **HTTP 200** (`sql/mongo/cache=true`) y disco raíz **35 % usado, 44 GB libres**. La infraestructura está funcionando en esta observación. La cobertura de todos los escenarios experimentales sigue parcialmente pendiente, como se indica arriba; evitar afirmar que una lectura sana resuelve las desconexiones WSREP históricas.

## 4. Última comprobación segura antes de entregar

Ejecutar **solo si se necesita evidencia final** desde Ubuntu, sin reiniciar servicios:

```bash
cd ~/distributedsystems
git status --short
docker compose ps
curl --noproxy '*' -fsS --max-time 10 http://localhost/api/health/deep
df -h /
```

Un resultado sano de esos comandos permite tomar la última captura. **No ejecutar `first-start.sh` con datos existentes, `down -v`, pruebas de partición ni cargas prolongadas con poco disco.**

## 5. Enlaces de presentación

- [README principal y repositorio](../README.md)
- [Diagrama JPG](arquitectura.jpg)
- [Arquitectura explicada](ARQUITECTURA.md)
- [Resultados y pruebas realizadas](RESULTADOS.md)
- [Tres capturas Nagios](evidencias/README.md)
- [Plan de pruebas (incluye pendientes)](PRUEBAS.md)

**Conclusión defendible:** la arquitectura y replicación multicapas están implementadas; se comprobaron continuidad parcial bajo fallos, recuperación y monitoreo, con resultados cuantificados. Las pruebas detectaron indisponibilidad real y pérdida temporal de componente primario en Galera. La infraestructura y el informe están disponibles en `main`, con los escenarios restantes y las limitaciones de una sola VM claramente señalados.
