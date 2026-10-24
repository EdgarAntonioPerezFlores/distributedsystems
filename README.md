# Sistema distribuido de tres capas — laboratorio VirtualBox

Proyecto académico basado en [tuxtter/distributedsystems](https://github.com/tuxtter/distributedsystems), con mejoras de MongoDB, Redis y acceso a Galera. El servidor corre en Ubuntu dentro de VirtualBox; el compañero genera tráfico desde otra computadora.

**Estado:** código y documentación preparados; verificaciones estáticas y pruebas unitarias focalizadas aprobadas. Arranque Docker, elecciones, carga y failover **pendientes de medir en la VM real**. Ver [VALIDACION.md](docs/VALIDACION.md). No se presenta como despliegue de producción.

## Empieza aquí

1. [Guía Ubuntu/VirtualBox y conexión del compañero](docs/GUIA-UBUNTU.md).
2. [Arquitectura y decisiones, con trazabilidad ToDo 2.1–2.3 y todo el punto 3](docs/ARQUITECTURA.md).
3. [Pruebas paso a paso: TEST-PLAN puntos 1–5](docs/PRUEBAS.md).
4. [Operación, backup y recuperación](docs/OPERACION.md).
5. [Plantilla de resultados para completar con mediciones](docs/RESULTADOS.md).

## Diagrama

<img width="5189" height="4789" alt="Diagrama en blanco" src="https://github.com/user-attachments/assets/2f796f10-6bbe-4dc2-ac00-1765a00ae0f0" />


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
- `docs/RESULTADOS.md`: completar nombres, recursos, reportes reales y conclusiones antes de entregar.

## Limitación fundamental

Los contenedores permiten demostrar resiliencia frente a fallos individuales. Una VM y un entry proxy siguen siendo puntos únicos de fallo. Una caída del host interrumpe todo el servicio. Para HA de infraestructura se requieren hosts independientes; eso queda fuera de esta práctica local.

El README original se conserva en [README-UPSTREAM.md](README-UPSTREAM.md); algunos comandos/nombres de ese documento y del TEST-PLAN original corresponden a la arquitectura anterior. Para ejecutar esta rama, seguir los documentos en `docs/`.
