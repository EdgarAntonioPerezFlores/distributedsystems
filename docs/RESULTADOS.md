# Informe de resultados — laboratorio de sistema distribuido

**Estado:** infraestructura y primera prueba de carga verificadas el **24 de octubre de 2026** con salidas de la VM compartidas por el estudiante. **Una prueba controlada de caída de `web1` ya se ejecutó; carga desde cliente externo, fallos de otros componentes y Chaos Engineering siguen pendientes** hasta contar con registros. No se inventan resultados.

## Equipo y entorno

- Servidor: Ubuntu en una VM de VirtualBox; Docker Compose, proyecto `distributed-ha-lab`.
- Fecha observada de prueba: 2026-10-24. Las rutas generadas por los scripts y sus marcas temporales utilizan UTC.
- IP LAN de la VM durante las pruebas: `192.168.1.88:80`; vía adaptador puente Wi-Fi. También se observó `192.168.1.87` en otro adaptador de la misma subred; conviene mantener solo uno para evitar enrutamiento ambiguo.
- Peticiones de verificación satisfactorias en `localhost` y `192.168.1.88`. **Esto no sustituye probar desde el equipo del compañero.**
- Máquina cliente externa, integrantes/matrícula, CPU/RAM/disco, versiones exactas de Docker/Compose, commit efectivamente desplegado y digests: **pendientes de registrar**.
- La prueba de carga inicial se lanzó desde la **propia VM**, no desde un cliente externo.
- Nagios: tras observarse `Exited (255)`, el estudiante proporcionó una nueva comprobación `docker compose ps -a nagios` con estado **`Up 3 minutes`**. Continúa pendiente documentar interfaz, alertas y MTTD/MTTR.

## Recuperación y nueva campaña de pruebas — 24 de octubre de 2026

Tras problemas de conectividad entre redes Docker, una desinstalación fallida de Docker Snap y el reinicio de la VM, se inspeccionaron los volúmenes existentes antes de recuperar los servicios. Los tres directorios Galera mostraban aproximadamente 284 MB cada uno; los tres volúmenes MongoDB usados por la configuración (`mongo7-1-data`, `mongo7-2-data`, `mongo7-3-data`) mostraban aproximadamente 306 MB cada uno, con archivos WiredTiger presentes. **La presencia de archivos por sí sola no prueba la integridad**, por lo que se verificó posteriormente el estado de los contenedores y las solicitudes HTTP.

La revisión posterior mostró los tres nodos Galera, los tres MongoDB y los tres Redis como `Up (healthy)`. `app1`, `app2` y `app3` se iniciaron con `docker compose start app1 app2 app3`; sus registros posteriores incluyeron `GET /health` con HTTP 200 para las tres API. La solicitud `curl --noproxy '*' -i --max-time 15 http://localhost/api/health/deep` respondió **HTTP 200** y los encabezados `x-request-trace` evidenciaron rutas como `presentation-lb-master -> webnode1 -> application-lb-master -> app2` y `presentation-lb-master -> webnode2 -> application-lb-master -> app1`.

Se registró una IP LAN posterior al cambio de Wi-Fi, `192.168.100.29`, diferente de la IP de las pruebas iniciales (`192.168.1.88`). El responsable reportó que el enlace LAN ya es accesible. **Aún no se ha aportado una ejecución documentada desde la computadora colaboradora**, por lo que no se le atribuyen resultados de carga o disponibilidad externa.

**Advertencias antes de repetir pruebas de fallo:** en un diagnóstico previo se observó asignación simultánea de una VIP a ambos Keepalived de presentación; se debe volver a comprobar la exclusividad de las VIP `172.30.0.250` y `172.31.0.250`. El disco de la VM reportó **95 % de ocupación** (aproximadamente 1.4 GB libres). También se observaron dos procesos `dockerd` (Snap y APT) y un bloqueo AppArmor de señales durante un reinicio anterior. El acceso HTTP recuperado no demuestra que todos esos riesgos hayan desaparecido.

### Segunda campaña — Prueba 1: estado general y verificación de servicios (24-10-2026)

**Origen:** salida compartida desde Ubuntu/VirtualBox, trabajando en la rama local `main`, sin cambios mostrados por `git status --short`. Archivo de evidencia en la VM: `results/baseline-repeticion.txt` (no incluido íntegro en el material aportado: se recibió el código de salida y sus últimas 80 líneas).

- `docker compose ps -a`: `app1`, `app2`, `app3`, los tres Nginx, HAProxy, Keepalived, los proxies SQL y Sentinel figuran `Up`. Galera 1–3, MongoDB 1–3 y Redis 1–3 figuran `Up (healthy)`. Los trabajos de inicialización `mongo-init` y `catalog-init` están `Exited (0)`, esperado para tareas de una sola ejecución.
- **Pendiente de recuperar:** `nagios` figura `Exited (255)` en esta nueva observación. Que hubiera funcionado en una comprobación anterior no sustituye su recuperación actual.
- `bash scripts/verify.sh > results/baseline-repeticion.txt 2>&1` terminó con **código de salida 0**. El script consulta salud profunda HTTP, estados Galera, estado del replica set MongoDB, Sentinel y nueve respuestas del catálogo. En un segundo envío se aportaron los estados específicos de Galera, MongoDB y Sentinel, registrados como Prueba 2.
- Las últimas líneas muestran respuestas **HTTP 200** y distribución real entre `webnode1`, `webnode2`, `webnode3` y `app1`, `app2`, `app3`. Se observó un `redis (cache miss) -> galera-via-proxy -> redis (cache write)` seguido de varios `cache hit`.
- Puerto externo publicado por `presentation-entry`: `0.0.0.0:80->80/tcp` y `[::]:80->80/tcp`.
- **Recursos de VM:** partición raíz de 25 GB con aproximadamente 22 GB usados, **1.4 GB disponibles (95 %)**. RAM total 11 GiB, 4.3 GiB usados, 7.0 GiB disponibles. El espacio disponible en disco es el principal límite inmediato para pruebas de carga prolongada.

**Resultado:** prueba general completada correctamente en cuanto al script de verificación (salida 0), comunicación HTTP, balanceo web/API y estados de contenedores. **Aprobación condicionada del laboratorio completo:** Nagios sigue detenido; las VIP y los roles/quórum quedaron confirmados posteriormente (Prueba 2), pero siguen pendientes las pruebas de conmutación y el mantenimiento del disco. No se ha ejecutado una nueva prueba de carga ni de failover.

**Siguiente secuencia sin provocar fallos:** una vez comprobados los estados del clúster y propietario único de las VIP (Prueba 2), verificar replicación y revisar la detención de Nagios. **No realizar fallos destructivos ni carga intensiva** hasta atender las advertencias y el espacio del disco.

### Segunda campaña — Prueba 2: clústeres, quórum y VIPs (24-10-2026)

**Origen:** líneas 35–125 de `results/baseline-repeticion.txt` y consulta `ip -4 -o addr show dev eth0` de los cuatro contenedores Keepalived; registros históricos `docker compose logs --tail=30 nagios`. Datos aportados por el responsable desde Ubuntu; **sin reinicios ni inyección de fallos en esta prueba**.

| Componente | Evidencia observada | Resultado |
|---|---|---|
| Galera 1–3 | En los tres: `wsrep_local_state_comment=Synced`, `wsrep_cluster_size=3`, `wsrep_cluster_status=Primary`, `wsrep_ready=ON` | Salud del clúster **aprobada** |
| MongoDB | `mongo3` PRIMARY, `mongo1` y `mongo2` SECONDARY; todos `health: 1` | Topología de réplica **aprobada** |
| Sentinel 1–3 | Los tres anuncian `172.28.0.23:6379` y `OK 3 usable Sentinels. Quorum and failover authorization can be reached` | Consenso/quórum **aprobado** |
| VIP presentación `172.30.0.250/24` | Presente solo en `presentation-keepalived-master` (IP base `172.30.0.11`); ausente en backup (IP `172.30.0.12`) | Propietario único **comprobado** |
| VIP aplicación `172.31.0.250/24` | Presente solo en `application-keepalived-master` (IP base `172.31.0.11`); ausente en backup (IP `172.31.0.12`) | Propietario único **comprobado** |
| Salud profunda | `{"sql":true,"mongo":true,"cache":true}` | API responde correctamente |
| Balanceo | Solicitudes HTTP 200 observadas entre `webnode1/2/3` y `app1/2/3` | Evidencia del reparto de solicitudes |

**Interpretación:** en esta muestra no existe asignación simultánea de VIP entre master y backup (problema observado en un diagnóstico anterior). Esto **no prueba todavía** que las VIP cambien de propietario cuando falla un HAProxy; la conmutación y su tiempo de recuperación continúan pendientes.

**Nagios:** el último estado aportado de `docker compose ps -a` es `Exited (255)`. Sus registros anteriores incluyen alertas `CRITICAL`/`OK` de `app1`, `app2`, `app3`, `web1`, `galera3` y `application-lb-master`; se observan transiciones `SOFT` y `HARD` y notificaciones generadas por Nagios/Postfix. La entrega local de correo a `nagios@localhost` **no equivale a demostrar un email recibido por el equipo**. Los mensajes muestran monitoreo previo, pero no explican la salida `255` ni demuestran monitoreo activo ahora. Hace falta inspeccionar el estado del contenedor, recuperarlo si es seguro y registrar observaciones actuales.

**Riesgos abiertos:** disco de la VM al 95 % (~1.4 GB libres), coexistencia previa de dos procesos Docker y reinicios problemáticos en AppArmor. Para futuras pruebas de carga/fallos, registrar espacio antes/después, confirmar todas las dependencias y detenerse ante nuevas respuestas 503.

**Siguientes ensayos:** replicación SQL controlada (sin detener nodos), comprobación de Redis master real e investigación/reinicio aislado de Nagios, manteniendo intactos los volúmenes.

### Segunda campaña — Prueba 3: replicación de datos Galera (24-10-2026)

**Objetivo:** demostrar replicación efectiva de una escritura SQL entre los tres miembros, además del estado `Synced` confirmado en la Prueba 2.

**Procedimiento ejecutado desde Ubuntu:**

1. Usando `bash scripts/sql.sh galera1`, se creó la tabla de prueba `lab_consistency (id INT PRIMARY KEY, value VARCHAR(80))`, si no existía, en la base `store`.
2. Se ejecutó `REPLACE INTO lab_consistency VALUES (1, 'evidencia-replicacion-2')` en `galera1`.
3. En cada uno de `galera1`, `galera2` y `galera3` se ejecutó `SET SESSION wsrep_sync_wait=1; SELECT * FROM lab_consistency WHERE id=1;` usando el mismo script.

| Nodo consultado | ID | Valor recuperado |
|---|---:|---|
| `galera1` | 1 | `evidencia-replicacion-2` |
| `galera2` | 1 | `evidencia-replicacion-2` |
| `galera3` | 1 | `evidencia-replicacion-2` |

**Resultado: APROBADA.** La escritura realizada en `galera1` pudo leerse desde los tres nodos mediante consultas con espera causal. Es una verificación concreta de replicación/visibilidad del registro; **no** implica que se hayan medido tiempos de réplica, rendimiento de escritura o tolerancia a la caída de un nodo. La tabla/registro quedan en la base de datos como evidencia de laboratorio.

**Diagnóstico adicional de Nagios:** `docker inspect distributed-ha-lab-nagios-1 --format 'Estado={{.State.Status}} Salida={{.State.ExitCode}} OOM={{.State.OOMKilled}} Error={{.State.Error}}'` devolvió `Estado=exited Salida=255 OOM=false Error=`. El contenedor sigue detenido; Docker no informa terminación por OOM y el campo de error está vacío. **Causa exacta todavía no determinada.** La próxima intervención debe limitarse al monitoreo, preservando los contenedores y los volúmenes de las bases de datos.

### Segunda campaña — Prueba 4: aplicación, escritura y lectura de MongoDB (24-10-2026)

**Comando en Ubuntu:** `python3 tests/functional.py http://localhost`. Este script consulta `/api/health/deep`, obtiene el catálogo SQL sin caché, comprueba su orden por precio, inserta una reseña de prueba mediante `POST /api/products/{sku}/reviews` y confirma su lectura con `GET` a la misma ruta.

**Resultado observado:** `PASS: health, SQL, catálogo ordenado, escritura/lectura MongoDB. Review: test-e77dd078ad844cc19496252f05ded1dd`. Se notificó que la reseña queda guardada como evidencia. **Aprobada** la prueba funcional de punta a punta, incluida escritura y lectura de la reseña por API. **No se ha comprobado aún la lectura directa de ese documento en las dos réplicas SECONDARY** ni se ha provocado una elección de nuevo PRIMARY. La prueba fue **local en la VM**, no ejecutada desde un segundo equipo de la LAN.

**Recuperación parcial de Nagios:** `docker compose start nagios` informó `Started`, y `docker compose ps -a nagios` mostró `Up 11 seconds`, con puerto publicado únicamente en `127.0.0.1:8088->80/tcp`. Sin embargo, `curl -I --max-time 10 http://127.0.0.1:8088/nagios/` falló con `curl: (56) Recv failure: Conexión reinicializada por la máquina remota`. Por lo tanto, **no se considera recuperada la interfaz HTTP del monitoreo**: es necesario inspeccionar registros recientes, revisar si el contenedor permanece activo y probar `GET` desde loopback. `curl -I http://192.168.100.29/nagios/` devolvió **404** de Nginx/HAProxy de presentación (`x-web-node: webnode3`), resultado esperado porque el puerto 80 de la IP LAN corresponde a la **aplicación**, no al Nagios publicado en loopback: ese 404 no diagnostica Nagios.

El arranque de Nagios también mostró verificaciones satisfactorias de dependencias (Galera, MongoDB y un nodo Redis `Healthy`) y reejecución satisfactoria de `mongo-init` y `catalog-init` mediante Compose; `Exited (0)` para tareas de inicialización no se interpreta como error. No hay evidencia de pérdida de datos en la prueba funcional, pero hay que vigilar el comportamiento de Compose cuando se inician servicios con dependencias.

**Pendiente antes de afirmar monitoreo operativo:** estado actual del contenedor, `docker compose logs --tail=80 nagios` y respuesta de `GET http://127.0.0.1:8088/nagios/`. Mantener sin publicar el puerto 8088 a la LAN.

**Seguimiento de Nagios (24-10-2026, 21:16 UTC según cabecera HTTP observada):** una nueva consulta mostró `docker compose ps -a nagios` con `Up 12 minutes` y puerto `127.0.0.1:8088->80/tcp`. Pese a permanecer activo, `curl --noproxy '*' -i --max-time 15 http://127.0.0.1:8088/nagios/` siguió devolviendo `curl: (56) Recv failure: Conexión reinicializada por la máquina remota`. La petición `curl -I http://192.168.100.29/nagios/` obtuvo `HTTP/1.1 404 Not Found` con cabeceras `x-web-node: webnode3` y `x-presentation-lb: presentation-master`, que corresponden al servicio de presentación en el puerto 80, **no** al endpoint de Nagios. El monitoreo no se marca aún como operativo. Pendiente comprobar logs recientes, procesos HTTP dentro del contenedor y conectividad interna frente a la publicación del puerto Docker, sin reiniciar los datos.

**Diagnóstico interno adicional de Nagios (24-10-2026):** `docker compose exec -T nagios sh -c 'ps -ef | grep -E "[a]pache|[h]ttpd|[n]agios"'` mostró el proceso principal `/opt/nagios/bin/nagios`, trabajadores de Nagios, y al supervisor `runsv apache`, pero **no mostró un proceso servidor Apache/httpd**. Una solicitud desde dentro del mismo contenedor a `http://127.0.0.1/nagios/` falló con `curl: (7) Failed to connect to 127.0.0.1 port 80 ... Couldn't connect to server`. Por tanto, el problema de acceso a `127.0.0.1:8088` se reproduce **internamente**, antes de la publicación Docker de puertos; se necesita comprobar el estado del servicio Apache bajo runit, validar su configuración y consultar logs de arranque. No se ha demostrado todavía la causa raíz ni se han modificado redes o volúmenes.

**Nagios: Apache aparentemente bloqueado por registro de PID (24-10-2026):** una nueva lectura de `docker compose logs --since=15m --tail=80 nagios` devolvió reiteradamente `httpd (pid 19) already running` (aproximadamente 80 líneas similares). A pesar de ese mensaje, `ps -ef | grep -E "[a]pache|[h]ttpd|[n]agios"` no mostró ningún proceso servidor Apache/httpd; sí mostró `runsv apache` y procesos de Nagios. Desde dentro del contenedor, `curl http://127.0.0.1/nagios/` falló inmediatamente con código `(7)`, sin servicio escuchando en el puerto 80. Esto **sugiere** archivo PID obsoleto o referencia al PID 19 correspondiente a otro proceso, pero **aún no se confirma**: falta comprobar qué proceso ocupa PID 19, ruta y contenido del PidFile y `apache2ctl configtest`. Ningún archivo PID ni servicio se modificó durante este diagnóstico. Se mantiene Nagios como **monitoreo web no operativo**.

**Causa identificada del fallo Apache/Nagios (24-10-2026):** la consulta de procesos confirmó que **PID 19 corresponde a `rsyslogd -n -f /etc/rsyslog.conf`**, mientras `/run/apache2/apache2.pid` y `/var/run/apache2/apache2.pid` contienen ambos `19`. El supervisor indica `down: apache: 0s, normally up, want up`; `apache2ctl configtest` concluye **`Syntax OK`** con advertencia no fatal de variable `TZ` indefinida. Los logs de Apache incluyen aviso histórico `AH00098: pid file ... overwritten -- Unclean shutdown of previous Apache run?` y la salida de Compose repite `httpd (pid 19) already running`. En conjunto, **queda confirmado que el archivo PID conservado no identifica actualmente a Apache** y bloquea su arranque normal. La remediación propuesta es verificar otra vez el PID y quitar **solo** ese archivo obsoleto dentro del contenedor; **no** matar PID 19 (`rsyslogd`), no recrear contenedores ni alterar volúmenes. Aún no se ha aportado evidencia de aplicación de la corrección o recuperación de la interfaz HTTP.

**Nagios: recuperación confirmada de Apache y HTTP con autenticación (24-10-2026):** tras comprobar que `/run/apache2/apache2.pid` contenía PID `19` y que el proceso real `19` era `rsyslogd`, se eliminó **solo** ese PID obsoleto desde el contenedor y se ejecutó `sv up apache`. La salida inicial fue `Archivo PID obsoleto eliminado.` y `run: apache: (pid 6185) 3s`. Una segunda comprobación indicó `run: apache: (pid 6185) 15s` y mostró al Apache principal `/usr/sbin/apache2 -D NO_DETACH` (PID `6185`) y cinco procesos trabajadores (`6188`–`6192`). La petición `curl --noproxy '*' -i --max-time 15 http://127.0.0.1:8088/nagios/` devolvió **HTTP/1.1 401 Unauthorized**, encabezado `Server: Apache/2.4.58 (Ubuntu)` y `WWW-Authenticate: Basic realm="Nagios Access"`: el servidor web está escuchando y su autenticación básica se exige correctamente. **Resultado: recuperación de Apache/HTTP APROBADA.** No se ha comprobado todavía un inicio de sesión autenticado ni el estado actual de todos los hosts/servicios del panel Nagios. El puerto `8088` continúa limitado a `127.0.0.1` del host; se mantiene `192.168.100.29:80` para la aplicación distribuida y no se requiere publicar Nagios en la LAN. No se reiniciaron Docker ni los contenedores de Galera/MongoDB/Redis para solucionar Apache.

**Acceso SSH para colaboradora Windows (24-10-2026):** en la VM Ubuntu se instaló/habilitó `openssh-server`; `sudo systemctl enable --now ssh` terminó correctamente, y `systemctl status ssh` confirmó **`Active: active (running)`**, `enabled`, proceso `sshd` PID `233490` y listeners `0.0.0.0:22` y `[::]:22`. `sudo ss -lntp | grep ':22 '` confirmó los sockets. `sudo ufw status` devolvió `Estado: inactivo`. Se intentó ejecutar `Test-NetConnection 192.168.100.29 -Port 22` en la terminal Ubuntu y devolvió `no se encontró la orden`, porque **esa instrucción corresponde a PowerShell de Windows**: **no constituye una prueba de conexión fallida**. El acceso por SSH desde la laptop Windows, la cuenta restringida y el túnel local hacia `127.0.0.1:8088/nagios/` siguen pendientes de comprobar. No se modificó Docker Compose ni se publicó Nagios en la LAN.

**Verificación de acceso de la colaboradora desde Windows (confirmación posterior):** el responsable confirmó que su compañera **ya pudo visualizar Nagios desde su laptop Windows** tras configurar OpenSSH en Ubuntu y seguir el procedimiento de túnel SSH local a `127.0.0.1:8088`. **Resultado: acceso remoto privado al panel comprobado por reporte del usuario.** No se aportaron todavía captura del panel, resultado de inicio de sesión detallado, estados actuales de los servicios desde Windows ni evidencias cuantitativas de alerta y recuperación durante un fallo. No se infiere que se haya abierto `192.168.100.29:8088` en la LAN; el acceso previsto sigue siendo a través del túnel SSH. Pendiente documentar capturas sin credenciales y ensayar alertas controladas.

### Segunda campaña — Evidencia del panel Nagios en laptop Windows (24-10-2026)

**Origen:** captura de pantalla aportada por el estudiante de la vista **Service Status Details For All Hosts** de Nagios Core, accesible mediante túnel SSH desde Windows. En la captura se observa el resumen de estado del monitoreo y la tabla de servicios. La imagen está compartida en la conversación, pero **el archivo PNG todavía no se ha incorporado al repositorio**.

| Estado de Nagios en la captura | Conteo |
|---|---:|
| Hosts **UP** | **24** |
| Hosts DOWN / UNREACHABLE / PENDING | **0 / 0 / 0** |
| Servicios **OK** | **30** |
| Servicios WARNING / UNKNOWN / CRITICAL / PENDING | **0 / 0 / 0 / 0** |

En las filas visibles se muestran estados `OK` para `app1`–`app3` (HTTP de aplicación y verificación de dependencias), balanceadores de aplicación y presentación, `db-proxy1/2`, `galera1/2/3`, `mongo1/2/3`, `redis1/2/3`, `sentinel1/2/3` y `web1/2/3`. La captura confirma que el panel presentó **24 hosts accesibles y 30 comprobaciones de servicio en OK**, sin alertas abiertas en ese momento; **no** demuestra que una alerta crítica se haya generado ni que se haya medido su tiempo de detección/recuperación.

**Siguiente experimento propuesto, aún no ejecutado:** fallo reversible de un nodo web redundante, con supervisión de Nagios desde Windows, captura de alerta `CRITICAL` y de recuperación `OK`, manteniendo el catálogo accesible. Preparar condiciones de espacio/servicios primero: la VM había informado 95 % de disco usado. Los estados `WARNING` y `UNKNOWN` son resultados de checks según umbrales o errores de comprobación; para mostrarlos sin confundirlos con fallas reales se puede crear después un servicio de prueba explícitamente simulado usando un plugin de Nagios. No marcar ninguna de esas transiciones como realizada hasta recibir evidencia.

### Segunda campaña: mediciones por repetir

| Prueba | Estado de esta segunda campaña | Evidencia pendiente |
|---|---|---|
| Salud de los servicios y contenedores | **Repetida: verify.sh terminó con código 0; Nagios detenido** | `results/baseline-repeticion.txt` en VM; log parcialmente compartido |
| Galera, MongoDB y Redis Sentinel | **Comprobados:** Galera Synced/Primary/3, Mongo 1 PRIMARY + 2 SECONDARY, Sentinel quorum 3 | Líneas 35–125 de `results/baseline-repeticion.txt` |
| VIPs de Keepalived | **Comprobadas:** propietario único en cada master | Salida de `ip -4 -o addr show dev eth0` en las cuatro instancias |
| Cliente LAN / compañera | Página accesible según reporte; pruebas instrumentadas pendientes | Solicitudes y capturas desde segundo equipo |
| MongoDB: funcional (Prueba 4) | **Aprobada** escritura/lectura mediante API; replicas SECONDARY pendientes | `tests/functional.py`, marcador `test-e77dd078ad844cc19496252f05ded1dd` |
| Rendimiento desde LAN | Pendiente | Peticiones, fallos, RPS, p95, p99, recursos |
| Fallo controlado de `app1` | Pendiente | Sonda continua, recuperación y servicio del resto de API |
| Failover de HAProxy/Keepalived | Pendiente; condicionado a corregir/verificar VIP | Antes/durante/después de la elección |
| Nagios | **Panel confirmado desde Windows: 24 hosts UP y 30 servicios OK** | Alertas de fallo y recuperación aún pendientes |

Los valores medidos en la primera campaña se conservan más abajo como evidencias históricas y **no deben copiarse como resultados de esta segunda campaña**.

## Salud y balanceo observados

La salida de `bash scripts/verify.sh | tee results/baseline.txt` mostró:

- **Galera:** `galera1`, `galera2`, `galera3` con `wsrep_local_state_comment=Synced`, `wsrep_cluster_status=Primary`, `wsrep_cluster_size=3` y `wsrep_ready=ON`.
- **MongoDB:** `mongo2` PRIMARY; `mongo1` y `mongo3` SECONDARY; salud 1 para los tres.
- **Redis Sentinel:** `CKQUORUM cachemaster` satisfactorio en los tres Sentinel; en ese instante los tres reportaron master `172.28.0.23:6379`.
- **API profunda:** `{"sql":true,"mongo":true,"cache":true}`.
- **Balanceo de presentación y aplicación:** las cabeceras `x-request-trace` mostraron `webnode1/2/3` y `app1/2/3` durante la verificación; respuestas HTTP 200.
- **Caché:** se observó al menos un `cache miss` que consultó Galera vía proxy y posteriores `cache hit`.
- **Keepalived:** después de recrear solamente los cuatro contenedores, figuraban `Up` durante aproximadamente 29 minutos; aún falta ensayar el desplazamiento de VIP tras fallo del balanceador.
- **Nagios:** previamente registró alertas CRITICAL/OK; se confirmó posteriormente `Up 3 minutes` en `docker compose ps -a nagios`. Aún no se han cuantificado MTTD/MTTR.

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

## Primer ensayo de tolerancia a fallos: caída controlada de `web1`

- **Fecha:** 2026-10-24 (marcas temporales UTC).
- **Sonda:** `python3 tests/probe.py http://192.168.1.88 --seconds 150 --out results/sonda-fallo-web1.csv`, ejecutada en la VM.
- **Inyección:** `bash scripts/fault.sh stop web1 30`.
- **Inicio registrado de la inyección:** `2026-10-24T15:57:43Z`; **recuperación solicitada:** `2026-10-24T15:58:16Z`. Estas marcas no equivalen por sí solas a MTTD ni MTTR medidos.
- **Muestras de sonda:** 145; **muestras exitosas:** 144; **muestras fallidas:** 1; **disponibilidad muestreada:** **99.3103448275862 %**.
- **Verificación posterior:** `docker compose ps web1 web2 web3` mostró los tres `Up`; `bash scripts/verify.sh > results/verification-after-web1.txt 2>&1` devolvió **código 0**.
- **Observación posterior:** las últimas cinco muestras del CSV reportaron HTTP 200 con rutas que incluyeron distintos `webnode` y `app`.
- **Nagios:** comprobación independiente previa con estado `Up 3 minutes`.
- **Evidencia local en la VM:** `results/sonda-fallo-web1.csv`, `results/verification-after-web1.txt`, archivo `results/fault-*-web1.log` generado por el script. **Estos archivos todavía deben subirse después de revisar que no contengan secretos.**

**Interpretación:** se observó continuidad en 144 de 145 comprobaciones y recuperación del nodo detenido. No se puede atribuir aún la única muestra fallida exactamente al instante de caída sin inspeccionar su marca temporal. Tampoco se puede afirmar disponibilidad de peticiones bajo carga: `probe.py` es una sonda aproximadamente una vez por segundo, no un generador de carga. Como la sonda se ejecutó en la VM, no representa una medición desde la computadora de un compañero.

**Precaución observada:** al recuperar `web1`, `docker compose start web1` también desencadenó comprobaciones y nuevas ejecuciones de `mongo-init` y `catalog-init` por dependencias de Compose. Las siguientes pruebas deben supervisar ese comportamiento y evitar atribuir interrupciones exclusivamente al componente elegido hasta revisar los eventos.

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
| Fallo controlado de web1 | 30 s de parada solicitada; sonda 150 s | — | — | 144 / 145 muestras exitosas; 99.31 % muestreado | Pendiente | `results/sonda-fallo-web1.csv` (VM) | Ejecutado; una muestra fallida |
| Failover API/LB/SQL/Redis/Mongo | Un fallo por escenario | — | — | — | — | Pendiente | No ejecutado |
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
| 3 | Failover de web/API/LB/Galera/proxy/Redis/Mongo y continuidad | web1 medido (144/145); otras capas pendientes |
| 4 | Chaos Monkey, red, recursos y límites | Pendiente |
| 5 | Nagios, MTTD/MTTR, alertas y presupuesto de error | Pendiente |

## Ejecución y recolección

Seguir `docs/PRUEBAS.md` **por etapas**, no todos los fallos a la vez. Confirmar un baseline sano antes y después de cada ensayo. Guardar `results/` con salidas reales, excluir contraseñas y secretos. Enviar a GitHub solamente los resultados inspeccionados. No utilizar `docker compose down -v`.

## Conclusión provisional

La VM ha demostrado funcionamiento de clústeres Galera y MongoDB, quórum Redis Sentinel, balanceo entre tres web/API y una primera carga local de 9107 peticiones sin fallos reportados por ApacheBench. Se observó continuidad parcial (144/145 muestras) y recuperación en la caída de un servidor web. **No se ha demostrado aún tolerancia a caída de un balanceador, HA de host, disponibilidad externa sostenida o Chaos Engineering**. Una sola VM y el contenedor de entrada constituyen puntos únicos de fallo; no se afirma despliegue en AWS ni disponibilidad de producción.
