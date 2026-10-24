# Entrega del sistema distribuido — resumen verificable

**Fecha de revisión:** 24 de octubre de 2026. **Repositorio y rama:** [EdgarAntonioPerezFlores/distributedsystems · main](https://github.com/EdgarAntonioPerezFlores/distributedsystems/tree/main).

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

- Verificación general `scripts/verify.sh` finalizó con **código 0** en las comprobaciones reportadas.
- **Galera:** 3 nodos `Synced`, clúster `Primary`, tamaño 3, más escritura SQL en un nodo y lectura del registro desde los tres.
- **MongoDB:** 1 PRIMARY y 2 SECONDARY saludables; prueba de escritura y lectura de reseña mediante API aprobada.
- **Redis Sentinel:** tres Sentinel con quórum disponible; se observaron `cache miss` y `cache hit`.
- **Keepalived:** propiedad exclusiva de cada VIP en el master, comprobada en el momento de la inspección; **no** se ha demostrado todavía la transferencia automática al backup durante una caída.
- **Web y API:** respuestas HTTP 200, distribución observada entre `web1–3` y `app1–3`.
- **Carga local básica:** 9,107 peticiones / 30 s / concurrencia 5 / **303.56 RPS**, sin fallos reportados por ApacheBench; **no** es una medición desde otra laptop.
- **Caída reversible de `web1`:** parada programada de 120 s y recuperación; los tres web quedaron `Up` y `verify.sh` regresó código 0. Un ensayo anterior registró 144 respuestas exitosas en 145 muestras de sonda local.
- **Nagios:** validación de configuración con **0 errores** y 24 advertencias de contactos de hosts; panel autenticado accesible desde Windows mediante túnel SSH. Tres capturas muestran **24 hosts UP → 23 UP / 1 DOWN → 24 UP**, con **30 servicios OK** durante las capturas. **No se documentó un servicio CRITICAL.**

Detalles, salidas y límites: [RESULTADOS.md](RESULTADOS.md) y [evidencias/README.md](evidencias/README.md).

## 3. Pendientes reales, separados de los entregables básicos

**Para cerrar la entrega sin nuevas pruebas peligrosas:**
1. Completar los **nombres de los integrantes**, grupo/materia y fecha de entrega, si el profesor lo solicita. No se han proporcionado aquí, por lo que no se inventan.
2. Si exigen capturas de ejecución además de Nagios, guardar una imagen de la aplicación `http://192.168.100.29/` y otra de la salida final `docker compose ps` / `scripts/verify.sh` sin credenciales.
3. Revisar el disco de la VM: anteriormente se reportó **95 % de uso**. No borrar volúmenes, ni usar `docker compose down -v`.

**Actualización de alcance por enunciado completo (24-10-2026):** el profesor **sí exige ejecutar los puntos 1 al 5 de [TEST-PLAN](../resilience-lab/TEST-PLAN.md)**, además de entregar diagrama, Markdown y IaC. Por tanto, **el proyecto aún no está concluido en la parte experimental**: faltan carga sostenida/estrés/spike/soak y recursos; failover real de balanceadores y nodos de datos; una ejecución del Chaos Monkey; y métricas de observabilidad como MTTD/MTTR. No se darán por terminados escenarios no ejecutados. Consulta el [checklist exhaustivo de pruebas pendientes](PENDIENTES-TEST-PLAN.md) y los [procedimientos](PRUEBAS.md).

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

**Conclusión defendible:** los componentes requeridos están implementados y la aplicación distribuida ha mostrado funcionamiento, replicación y recuperación de un web. La infraestructura y la documentación están disponibles en `main`. Se identifican con transparencia las pruebas extendidas todavía no realizadas y la limitación de ejecutar todo sobre una sola VM.
