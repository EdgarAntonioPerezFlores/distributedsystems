# MongoDB y el kernel de Ubuntu

El arranque en la VM falló con SERVER-121912: la imagen MongoDB 8.0 rechazó el kernel Linux. La matriz oficial indica que MongoDB 7.0 no está afectado por este problema. El laboratorio usa ahora la imagen oficial mongo:7.0.45-jammy en mongo1, mongo2, mongo3 y mongo-init.

Se mantienen tres miembros del replica set rs0, autenticación por keyfile y escrituras majority. Se usan volúmenes separados mongo7-1-data, mongo7-2-data y mongo7-3-data. Los antiguos mongo1-data, mongo2-data y mongo3-data se conservan: no se borran ni se abren con MongoDB 7. Esto inicia una instancia de datos nueva; no migra datos de MongoDB 8. Si una instalación anterior tenía reseñas reales, requiere un plan de migración por separado.

Para continuar desde el fallo inicial, con Galera ya en ejecución:

```bash
cd ~/distributedsystems
git pull --ff-only origin main
docker compose pull mongo1 mongo2 mongo3 mongo-init
docker compose up -d --no-deps --wait --wait-timeout 300 mongo1 mongo2 mongo3
docker compose up -d
```

Ejecutar cada paso solo si terminó correctamente el anterior. La espera de MongoDB no inicializa todavía el replica set; lo hace mongo-init al iniciar el resto. Después comprobar:

```bash
docker compose ps -a
docker compose logs --no-color --tail=80 mongo-init catalog-init
curl -i http://localhost/api/health/deep
```

No usar first-start.sh, repair-initial-passwords.sh ni down -v para este paso; Galera ya fue inicializado. Si algún servicio falla, revisar su log específico. No se cambió el kernel de Ubuntu ni se desactivó la protección de MongoDB.

Validación realizada: YAML y comparación de configuración; solo cambian los cuatro servicios MongoDB y se agregan los tres volúmenes nuevos. Galera y los demás servicios quedan iguales. Descarga y arranque de esta imagen pendientes de comprobar en la VM.

Fuentes:
- https://jira.mongodb.org/browse/SERVER-125742
- https://jira.mongodb.org/browse/SERVER-136848
- https://hub.docker.com/_/mongo/tags
