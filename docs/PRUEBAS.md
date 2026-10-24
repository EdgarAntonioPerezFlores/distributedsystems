# Plan ejecutable: puntos 1 a 5 de TEST-PLAN.md

**Estado: preparado, pendiente de ejecutar en la VM y desde el cliente externo.** No se presentan resultados de carga inventados. El plan original está en `resilience-lab/TEST-PLAN.md`; este documento adapta sus comandos y expectativas a las mejoras.

Convenciones: **SERVIDOR** = terminal de Ubuntu/VirtualBox en la raíz del repo. **CLIENTE** = equipo de tu compañero. En Linux/WSL instalar `apache2-utils siege curl python3`; en Windows se puede usar JMeter nativo y `curl.exe` o WSL. Ambos deben registrar la misma zona horaria (los scripts usan UTC) y comprobar sincronización: `timedatectl status` en Ubuntu y hora automática en Windows. No modificar el reloj del host para estas pruebas.

## 1. Baseline y funcionalidad

SERVIDOR:

```bash
mkdir -p results
bash scripts/verify.sh | tee results/baseline.txt
docker stats --no-stream $(docker compose ps -q) > results/stats-iniciales.txt
docker compose images > results/images.txt
docker image ls --digests > results/image-digests.txt
```

Esperar tres Galera `Primary/Synced`, tamaño 3; MongoDB un PRIMARY y dos SECONDARY; Sentinel `CKQUORUM` correcto en los tres; API deep 200; tres web y API en funcionamiento. Revisar VIPs:

```bash
docker compose exec presentation-keepalived-master ip -4 addr
docker compose exec presentation-keepalived-backup ip -4 addr
docker compose exec application-keepalived-master ip -4 addr
docker compose exec application-keepalived-backup ip -4 addr
docker compose exec presentation-lb-master wget -qO- 'http://127.0.0.1:8404/stats;csv'
docker compose exec application-lb-master wget -qO- 'http://127.0.0.1:8404/stats;csv'
```

Cada VIP debe estar en una sola pareja activa. Los backends web/API deben estar UP. Para SQL, desde `db-proxy1` consultar `http://127.0.0.1:8404/stats;csv` del mismo modo; los Galera elegibles pueden figurar UP aunque sean backup.

CLIENTE (cambiar la IP):

```bash
export BASE=http://192.168.1.80
mkdir -p results
python3 tests/functional.py "$BASE" | tee results/functional.txt
for i in $(seq 1 12); do curl -sS -D - "$BASE/api/products/cheapest" -o /dev/null; done | tee results/headers.txt
```

`X-Web-Node` debe mostrar los tres web; `x-request-trace` permite identificar API y caché. **`X-Presentation-LB` normalmente permanece en master**: hay activo/pasivo, no round-robin entre master y backup. El texto original es ambiguo en ese punto. Comprobar cambio de ese header durante failover, no exigir alternancia normal.

### Consistencia SQL real

SERVIDOR: crear una tabla exclusiva de prueba en un nodo y leerla en los otros con espera causal. No modifica precios del catálogo.

```bash
cat <<'SQL' | bash scripts/sql.sh galera1
CREATE TABLE IF NOT EXISTS lab_consistency (id INT PRIMARY KEY, value VARCHAR(80));
REPLACE INTO lab_consistency VALUES (1, 'evidencia-replicacion');
SQL
for n in galera1 galera2 galera3; do
 echo "$n"
 printf "SET SESSION wsrep_sync_wait=1; SELECT * FROM lab_consistency;\n" | bash scripts/sql.sh "$n"
done
```

Guardar la salida. Verificar también caché miss/hit:

```bash
curl -i -X POST http://localhost/api/cache/clear
curl -i http://localhost/api/products/cheapest
curl -i http://localhost/api/products/cheapest
```

## 2. Rendimiento desde la computadora del compañero

No probar solo `/`: eso mide principalmente HTML/Nginx. Para catálogo usar `/api/products/cheapest`; para SQL real añadir `?nocache=1`; para MongoDB usar `/api/products/ST-001/reviews`. Ejecutar escenarios por separado y repetir al menos 3 veces bajo condiciones comparables.

CLIENTE:

```bash
# Smoke
bash tests/load.sh "$BASE" 5 30
# Carga esperada 10 minutos; después repetir 30 minutos si hay margen
bash tests/load.sh "$BASE" 20 600
# Estrés gradual: detener el aumento cuando se observe saturación
for c in 10 25 50 100; do bash tests/load.sh "$BASE" "$c" 60; sleep 20; done
# Efecto de caché: calentar primero y comparar dos corridas
curl -fsS "$BASE/api/products/cheapest" > /dev/null
bash tests/load.sh "$BASE" 20 120 /api/products/cheapest
bash tests/load.sh "$BASE" 20 120 '/api/products/cheapest?nocache=1'
# Spike: ab crea concurrencia al empezar; no es una rampa precisa de usuarios
bash tests/load.sh "$BASE" 5 30
bash tests/load.sh "$BASE" 300 30
bash tests/load.sh "$BASE" 5 60
# Soak: 2 horas; vigilar crecimiento de RAM/conexiones
bash tests/load.sh "$BASE" 20 7200
```

Para el spike de 300, primero verifica la rampa de estrés. Si la VM ya falla a 50, registra ese límite y acuerda con el profesor el spike que realmente puede ejecutar; no lo presentes como 300 si no lo hiciste. Detener si hay swap sostenido, errores crecientes o pérdida de control de la VM.

Alternativa Siege para tráfico sostenido:

```bash
siege -b -c 20 -t 10M "$BASE/api/products/cheapest" 2>&1 | tee results/siege-10m.txt
```

### JMeter en Windows, Linux o macOS

Se incluye `tests/catalogo.jmx` listo para usar. Instala Java compatible y Apache JMeter desde [su sitio oficial](https://jmeter.apache.org/) y ejecuta, sustituyendo la IP:

```bash
jmeter -n -t tests/catalogo.jmx -Jhost=192.168.1.80 -Jport=80 -Jusers=20 -Jramp=10 -Jduration=600 -l results/carga.jtl -e -o results/reporte-carga
```

Para SQL sin caché añade `-Jpath=/api/products/cheapest?nocache=1`; en shells con expansión de comodines pon ese argumento entre comillas. `host` solo lleva la IP, sin `http://`. El plan comprueba HTTP 200; la prueba funcional valida datos. Para modificarlo en la GUI abre el archivo. Si prefieres construir tu propio plan, en la GUI crea **Test Plan → Thread Group → HTTP Request**, servidor `IP_VM`, puerto `80` (o `8080` con NAT), protocolo `http`, método GET, ruta `/api/products/cheapest`. Configura 20 threads, ramp-up 10 s, loop continuo, scheduler/duración 600 s. Añade una Response Assertion del código HTTP `200` y, si corresponde, una JSON Assertion de la estructura de catálogo. Guarda `catalogo.jmx` en `tests/`.

Ejecuta en modo sin interfaz para medir:

```bash
jmeter -n -t tests/catalogo.jmx -l results/carga.jtl -e -o results/reporte-carga
```

En Windows ejecuta `jmeter.bat` con los mismos argumentos. La carpeta HTML debe ser nueva/vacía para cada corrida. Para spike crea tres Thread Groups programados con 5, 300 y 5 usuarios y períodos sin solapamiento, ramp-up 1 s; para soak usa duración 7200 s. Los scripts JMeter del repo están en `resilience-lab/jmeter/`, pero su Compose local depende de una red Docker del servidor: **no ejecutar ese Compose sin cambios en el equipo remoto**. El compañero usa las herramientas nativas/WSL y la IP de Ubuntu.

### Capacidad por capa y conexiones

En SERVIDOR se pueden ejecutar pruebas internas suplementarias desde herramientas conectadas a la red correspondiente. No son mediciones remotas equivalentes; compiten por CPU con la aplicación. Para web y API:

```bash
docker build -t lab-ab-local resilience-lab/ab
docker run --rm --network distributed-ha-lab_edge --entrypoint ab lab-ab-local -l -n 1000 -c 10 http://web1/
docker run --rm --network distributed-ha-lab_application --entrypoint ab lab-ab-local -l -n 1000 -c 10 'http://app1:8080/products/cheapest?nocache=1'
```

`ab` mide HTTP, **no el protocolo SQL**. Para capacidad SQL usar `mariadb-slap` disponible en la imagen, durante una ventana separada (si la imagen ofrece `mysqlslap`, usar ese nombre):

```bash
docker compose exec galera2 bash -ec 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-slap --host=127.0.0.1 --user=root --create-schema=store --query="SELECT id,sku,price FROM products ORDER BY price LIMIT 10" --concurrency=10 --iterations=3 --number-of-queries=1000'
printf "SHOW GLOBAL STATUS WHERE Variable_name IN ('Threads_connected','Threads_running','Max_used_connections');\nSHOW VARIABLES LIKE 'max_connections';\n" | bash scripts/sql.sh galera2
```

El comando `mariadb-slap` anterior mide un nodo SQL directamente; compararlo con el camino vía API para separar el costo de red/API/caché. No atribuir una mejora a escalado sin comparar recursos iguales.

### Métricas que deben anotar

`ab`: Requests/sec, tiempo total, Completed/Failed requests, Non-2xx responses, p50/p95/p99 y errores de conexión. No sumar ciegamente categorías que pueden solaparse; usar JMeter con resultados individuales si se necesita disponibilidad exacta por solicitud. `ab -l` evita falsos fallos por tamaño variable; no comprueba el contenido, por eso se acompaña de la prueba funcional y la sonda JSON.

SERVIDOR, en otra terminal, muestreo cada 5 segundos:

```bash
while true; do date -u +%FT%TZ; docker stats --no-stream $(docker compose ps -q); sleep 5; done | tee results/stats-carga.txt
```

Detener con Ctrl+C. Vigilar CPU/RAM también en el cliente: puede ser el cuello de botella. Registrar Wi-Fi/Ethernet/VPN, número de usuarios, duración y configuración.

Objetivos propuestos para evaluar, NO resultados prometidos: baseline p95 < 200 ms y éxito ≥ 99.9%; durante fallos individuales éxito ≥ 99% y p95 < 500 ms. Ajustar con justificación a los recursos reales antes de medir. No extrapolar disponibilidad anual desde 3 minutos de prueba.

## 3. Alta disponibilidad y failover

Antes de **cada** fallo comprobar baseline. CLIENTE mantiene sonda y carga en dos terminales:

```bash
python3 tests/probe.py "$BASE" --seconds 240 --out results/sonda-nombre-experimento.csv
bash tests/load.sh "$BASE" 20 240 '/api/products/cheapest?nocache=1'
```

Son comandos para terminales separadas. Empezar 30 s antes de inyectar el fallo y seguir al menos 60 s después de recuperar. SERVIDOR ejecuta **una fila por vez** y valida salud completa antes de la siguiente:

| Fallo | Comando servidor | Qué comprobar |
|---|---|---|
| Web | `bash scripts/fault.sh stop web1 30` | Backends excluyen web1; los otros responden |
| API | `bash scripts/fault.sh stop app1 30` | Traces muestran app2/3; recuperación posterior |
| LB presentación | `bash scripts/fault.sh stop presentation-lb-master 30` | VIP se mueve, header muestra backup |
| LB aplicación | `bash scripts/fault.sh stop application-lb-master 30` | VIP aplicación cambia; API vuelve a responder |
| HAProxy suspendido | `bash scripts/fault.sh pause presentation-lb-master 30` | Chequeo HTTP activo de Keepalived detecta falta de respuesta |
| Galera preferido | `bash scripts/fault.sh stop galera1 60` | `/api/diagnostics/db` cambia de nodo; SQL sin caché funciona con quorum 2 |
| Galera secundario | `bash scripts/fault.sh stop galera2 30` | Clúster mantiene servicio y vuelve a 3 |
| Proxy SQL | `bash scripts/fault.sh stop db-proxy1 30` | API reintenta SELECT por db-proxy2 |
| Redis master actual | `bash scripts/fault.sh stop redisN 45` | Elegir N según Sentinel; nuevo master, sin perder catálogo |
| Mongo primary actual | `bash scripts/fault.sh stop mongoN 45` | Elegir N según rs.status; nuevo primary, reseñas persistentes |

`redisN`/`mongoN` son marcadores: no copiarlos literalmente. Averiguar el master actual con `scripts/verify.sh` antes de cada ensayo. Redis IP `.21/.22/.23` corresponde a redis1/2/3. MongoDB puede tener primary en cualquier miembro después de un fallo.

Durante el fallo de Galera:

```bash
# CLIENTE, repetidamente en otra terminal
curl -i "$BASE/api/diagnostics/db"
curl -i "$BASE/api/products/cheapest?nocache=1"
```

Durante MongoDB guardar una reseña con `tests/functional.py` **antes**, y volver a leerla **después** por `/api/products/SKU/reviews`. La sonda de catálogo sola no demuestra HA de MongoDB. Usar además `tests/probe.py --path /api/products/ST-001/reviews`; ejecutar escritura durante la elección y registrar si hubo 503, sin repetir ciegamente un POST que podría haber quedado confirmado.

Repetir stop, kill y pause en cada pareja LB. El tiempo de detección depende de advertencias VRRP, chequeos `interval=2`, `fall=2`, timeout y carga: medirlo, no asumir 3 segundos. `kill` puede activar `restart: unless-stopped` y el fallo durar menos de lo pedido; `stop` no se reinicia automáticamente. El script llama a `start` para recuperarlo. Revisa que la falla haya durado realmente lo medido.

### Negativas, reducción de capacidad y caché ausente

Después de cada bloque ejecutar `scripts/verify.sh` y esperar recuperación:

```bash
# SERVIDOR: dos web fuera (mantener medición remota)
docker compose stop web1 web2
sleep 30
docker compose start web1 web2
# Ambos LB de presentación: caída esperada
docker compose stop presentation-lb-master presentation-lb-backup
sleep 20
docker compose start presentation-lb-master presentation-lb-backup
docker compose restart presentation-keepalived-master presentation-keepalived-backup
# Repetir el bloque anterior con los nombres application-* para esa capa.
# Redis completo fuera: catálogo debe degradar a SQL
docker compose stop redis1 redis2 redis3
sleep 30
docker compose start redis1 redis2 redis3
# Entry único: caída total esperada
docker compose stop presentation-entry
sleep 15
docker compose start presentation-entry
```

Repetir reducción de capacidad con app1/app2. Si se interrumpe un bloque, ejecutar sus comandos `start`. No detener dos miembros de un clúster de datos salvo ensayo explícito de pérdida de quorum con backup: no es un escenario de disponibilidad esperada.

El plan upstream decía que detener `galera1` debía fallar; tras esta mejora el objetivo es continuidad SQL con recuperación transitoria. Del mismo modo, la caída de un Mongo/Redis ya debe probar elección, no solo una dependencia única perdida.

## 4. Chaos Engineering

Hipótesis → medición base → inyección → observación → recuperación → comparación. Empezar con web/API, una víctima simultánea. Usamos el **Chaos Monkey de contenedores incluido en este repo**, no el producto Netflix/Spinnaker.

SERVIDOR:

```bash
docker compose -f resilience-lab/docker-compose.yml up -d --build ab siege jmeter chaosmonkey
docker compose -f resilience-lab/docker-compose.yml exec -T \
 -e GROUP=web -e ACTION=stop -e MAX_CONCURRENT=1 \
 -e INTERVAL=30 -e DOWNTIME=10 -e DURATION=180 \
 -e PROBE_URL=http://presentation-entry/api/products/cheapest \
 chaosmonkey /runbook/run.sh /results/chaos-web-01
mkdir -p results/chaos-web-01
docker cp lab-chaosmonkey:/results/chaos-web-01/. results/chaos-web-01/
```

CLIENTE sigue ejecutando carga y sonda externa. El resumen del Monkey es observación interna; compararlo con el cliente. Cambiar `GROUP=app`, luego `ACTION=pause`/`kill` en corridas distintas. Para datos, solo una víctima, baseline sano y esperar resincronización antes de otra: el Monkey original no comprueba quorum ni `Synced` entre inyecciones. Preferir `fault.sh` manual para datos. No usar `GROUP=any` ni víctimas múltiples para demostrar disponibilidad sin plan específico.

| Familia del punto 4 | Experimento reproducible | Límite/recuperación |
|---|---|---|
| Contenedor | Comando anterior | Restaura al salir normalmente; revisar fallos de restauración |
| Latencia y jitter | `bash scripts/network-fault.sh app1 delay 30` | Añade 200 ± 50 ms en la interfaz de datos; restaura qdisc |
| Pérdida de paquetes | `bash scripts/network-fault.sh app1 loss 30` | 5% en tráfico saliente de esa interfaz |
| Ancho de banda | `bash scripts/network-fault.sh app1 bandwidth 30` | Limita a 128 kbit/s |
| Partición 2+1 Galera | `bash scripts/network-fault.sh galera2 partition 30` | 100% pérdida saliente; observar mayoría/minoría; no forzar bootstrap |
| Recursos/CPU | `docker update --cpus 0.25 $(docker compose ps -q app1)` bajo carga | Recuperar con `docker update --cpus 0 $(docker compose ps -q app1)` |
| Dependencia lenta | `bash scripts/network-fault.sh galera2 delay 30` | Registrar flow control y efectos de replicación; puede afectar al clúster |
| Compuesto | Cliente con carga + `fault.sh stop app1 30` + POST `/api/cache/clear` | Recuperar app1 y comprobar catálogos/latencia |
| Recuperación total | Parada limpia y `scripts/recover-clean.sh` | Ver runbook; usar backup y ventana de caída |
| Reloj | No ejecutado por defecto | Los contenedores comparten reloj del kernel; requiere VMs independientes |
| Disco lleno/memoria/FD | No ejecutados por defecto | Diseñar entorno desechable con volúmenes/cuotas separados; no llenar disco de la VM |

Registrar los escenarios no ejecutados como tales y acordar alcance con el profesor; no declarar «todo el punto 4 validado» por haber corrido solo el Monkey. `network-fault.sh` necesita kernel Linux con netem; si falla, guardar el error y marcar pendiente. Su pérdida es **saliente**, no una partición simétrica completa. Nunca usar `CAP_SYS_TIME` ni cambiar el reloj compartido para emular un único nodo.

## 5. Observabilidad y alertas

Nagios revisa TCP por instancia y chequeos de salud de Galera/API. Nuevos checks usan intervalo nominal de un minuto y reintento 0.2 minutos (según unidad de intervalo de Nagios); un fallo de 10 s puede no detectarse. Para esta prueba parar `web1` por 120 s, recoger transición y restauración. La detección y alertas son estados en Nagios; no se configuró envío de correo.

```bash
# SERVIDOR; mantener la sonda remota en paralelo
bash scripts/fault.sh stop web1 120
bash scripts/collect.sh
docker compose exec nagios /usr/local/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
```

La ruta del binario de Nagios puede variar por imagen: si no existe, usa `command -v nagios` dentro del contenedor o revisa su imagen; no confundir ese error con un fallo de servicio. Abrir la interfaz en Ubuntu y capturar el estado con hora, sin contraseñas. Si se necesita acceso remoto usar túnel SSH a loopback, no publicar la interfaz que controla Docker.

Comparar `results/fault-*.log`, logs API/HAProxy/Keepalived, Nagios y CSV del cliente. Registrar alertas omitidas, falsas y recuperación. Calcular por escenario:

- MTTD: detección − inyección; MTTR: recuperación estable − inyección. Para varios ensayos, promediar las duraciones y reportar dispersión.
- Definir recuperación estable como 10 respuestas válidas consecutivas más clúster sano. Documentar la definición.
- Disponibilidad por solicitudes: respuestas válidas / intentos, usando JMeter o logs individuales. La sonda calcula solo disponibilidad muestreada.
- Presupuesto de error: con SLO 99.9%, fracción permitida = 0.001; burn rate = fracción fallida observada / 0.001, siempre indicando ventana. Ejemplo matemático: 1% de fallos consume a 10×; no es un resultado del laboratorio.
- El CSV de sonda toma muestras aproximadamente cada segundo, con timeout de 3 s. Estimar la interrupción entre última respuesta buena, fallos y recuperación; **no** multiplicar número de fallos × 1 s como RTO exacto.

Completar [RESULTADOS.md](RESULTADOS.md) con datos medidos y enlazar los archivos crudos. Si una hipótesis falla, documentar el fallo y la causa probable: eso también es un resultado útil.
