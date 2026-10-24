# Sistema distribuido de tres capas — laboratorio VirtualBox

Proyecto académico basado en [tuxtter/distributedsystems](https://github.com/tuxtter/distributedsystems), con mejoras de MongoDB, Redis y acceso a Galera. El servidor corre en Ubuntu dentro de VirtualBox; el compañero genera tráfico desde otra computadora.

**Estado de entrega (24 de octubre de 2026):** los tres entregables base (**diagrama JPG, documentación Markdown y configuraciones/IaC**) están incorporados en `main`. Se verificaron 3 Galera, 3 MongoDB, quórum Redis Sentinel, balanceo web/API, replicación SQL, pruebas funcionales, carga local y recuperación de `web1`. **Nagios ya tiene tres capturas reales** (24 hosts UP → 23 UP/1 DOWN → 24 UP, 30 servicios OK). Quedan pendientes las pruebas de carga externa, failover completo y Chaos Engineering del plan ampliado; no son resultados que deban darse por hechos. Todo corre en una VM, no en producción. **[Consulta primero el resumen de entrega](docs/ENTREGA.md).**

## Empieza aquí

1. [Guía Ubuntu/VirtualBox y conexión del compañero](docs/GUIA-UBUNTU.md).
2. [Arquitectura y decisiones, con trazabilidad ToDo 2.1–2.3 y todo el punto 3](docs/ARQUITECTURA.md).
3. [Pruebas paso a paso: TEST-PLAN puntos 1–5](docs/PRUEBAS.md).
4. [Operación, backup y recuperación](docs/OPERACION.md).
5. [Resultados observados, con evidencias y pendientes](docs/RESULTADOS.md).
6. **[Resumen listo para la entrega y lo que falta](docs/ENTREGA.md).**

## Diagrama

![Diagrama de arquitectura del sistema distribuido](docs/arquitectura.jpg)

[Ver el JPG directamente](docs/arquitectura.jpg) · [Capturas reales de Nagios](docs/evidencias/README.md)


## Componentes

| Capa | Servicios |
|---|---|
| Entrada y presentación | Entry HTTP; HAProxy master/backup + Keepalived; 3 Nginx |
| Aplicación | HAProxy master/backup + Keepalived; 3 API Node.js |
| SQL | 2 HAProxy de base de datos; 3 Galera; checks HTTP de estado wsrep |
| Documentos | MongoDB replica set de 3 miembros; usuario de aplicación |
| Caché | Redis master + 2 réplicas; 3 Sentinel; caché desechable |
| Operación | Nagios; scripts de arranque, salud, backup y fallos |
| Pruebas | ab/Siege/JMeter desde cliente; Chaos Monkey local del repo |

## Arranque resumido

Solo con Docker Compose instalado y volúmenes nuevos; la guía explica instalación y red:

```bash
git clone https://github.com/EdgarAntonioPerezFlores/distributedsystems.git
cd distributedsystems
bash scripts/setup.sh
bash scripts/first-start.sh
bash scripts/runtime-validate.sh
```

Abrir `http://localhost` en Ubuntu o `http://IP_UBUNTU` desde el compañero. No compartir VIPs Docker como dirección remota.

**No usar `docker compose down -v` para reiniciar.** Para datos existentes y apagado completo seguir [el runbook](docs/OPERACION.md). No subir `.env`, claves o backups. Las credenciales se generan localmente.

## Prueba externa mínima

```bash
export BASE=http://IP_UBUNTU
python3 tests/functional.py "$BASE"
bash tests/load.sh "$BASE" 5 30
```

En pruebas de Galera usa `/api/products/cheapest?nocache=1` para no ocultar el fallo con caché. Para MongoDB prueba reseñas. Documentar tanto fallos como éxitos.

## Entregables

- Diagrama JPG y generador.
- Markdown de arquitectura, guía de red, operación y pruebas.
- `docker-compose.yml`, Dockerfiles, configuraciones HAProxy/Keepalived/MongoDB/Redis y cambios de API.
- Scripts de pruebas remotas, JMeter `.jmx`, fallos y evidencias.
- [Resumen de entrega](docs/ENTREGA.md) con referencias a las pruebas realizadas y pendientes.
- [Galería de Nagios](docs/evidencias/README.md): tres PNG publicados y documentados.
- `docs/RESULTADOS.md`: confirmar nombres/recursos/mediciones de la VM antes de presentar la entrega.

## Limitación fundamental

Los contenedores permiten demostrar resiliencia frente a fallos individuales. Una VM y un entry proxy siguen siendo puntos únicos de fallo. Una caída del host interrumpe todo el servicio. Para HA de infraestructura se requieren hosts independientes; eso queda fuera de esta práctica local.

El README original se conserva en [README-UPSTREAM.md](README-UPSTREAM.md); algunos comandos/nombres de ese documento y del TEST-PLAN original corresponden a la arquitectura anterior. Para ejecutar y validar la rama `main`, seguir los documentos en `docs/`.
