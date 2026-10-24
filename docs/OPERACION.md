# Operación, reinicio y recuperación

## Diagnóstico inicial

```bash
docker compose ps -a
docker compose logs --tail=150 galera1 galera2 galera3 mongo-init catalog-init app1
curl -i http://localhost/api/health/deep
bash scripts/verify.sh
```

No borrar volúmenes al ver un 503. Es común esperar a que Galera sincronice, MongoDB elija primary y `catalog-init` termine. Si se modificaron credenciales después del primer arranque, cambiar `.env` no cambia los usuarios guardados en las bases; se necesita una rotación coordinada.

Redes internas: `172.30.0.0/24`, `172.31.0.0/24`, `172.28.0.0/24`. Si coinciden con tu LAN/VPN, cambiar subredes **y** VIPs, configuraciones Keepalived/HAProxy/Nginx, IPs Redis/Sentinel y scripts de red de forma consistente antes del primer arranque.

## Arranque cotidiano y parada limpia

Si solo cayó un servicio y otros Galera siguen `Primary`, iniciarlo normalmente; no hacer bootstrap. Al recrear un LB, recrear/reiniciar el Keepalived que comparte su namespace. Al recrear Galera, reiniciar su `galera-checkN`.

```bash
docker compose start app1
docker compose start galera1
docker compose restart galera-check1
```

Para apagar todo el laboratorio, guardar backup, parar tráfico y detener primero app/proxies, después Galera 3, 2 y finalmente 1:

```bash
bash scripts/backup.sh galera2
docker compose stop presentation-entry app1 app2 app3 db-proxy1 db-proxy2
docker compose stop -t 120 galera3
docker compose stop -t 120 galera2
docker compose stop -t 120 galera1
docker compose stop
```

Después de una parada **limpia**, con todos los nodos Galera detenidos:

```bash
bash scripts/recover-clean.sh
bash scripts/verify.sh
```

El script solo arranca un nodo marcado `safe_to_bootstrap=1` con secuencia conocida; no fuerza ese marcador. Una vez hay tres miembros elimina el bootstrap automático del contenedor. Si falla la verificación, no continuar con pruebas. Si existe una recuperación automática parcial con nodos corriendo, inspeccionar estado y logs antes de detenerlos o intentar bootstrap.

## Apagón/caída completa no limpia

No ejecutar a ciegas `GALERA_BOOTSTRAP=yes docker compose up`: puede iniciar desde un nodo atrasado. Mantener detenidos los tres nodos, preservar copias de sus volúmenes, revisar `grastate.dat` y UUID/seqno. Si seqno es -1, recuperar la posición con `--wsrep-recover` según la versión/imagen. Elegir el estado más avanzado, confirmar el candidato con el procedimiento oficial, y hacer bootstrap **en uno solo**. Incorporar luego los otros dos y verificar datos, quorum y eliminación del flag de bootstrap.

El procedimiento de apagón no está automatizado en esta entrega porque necesita inspeccionar las posiciones reales. Documentar el resultado y la decisión. Fuente: [MariaDB: recuperación del Primary Component](https://mariadb.com/docs/galera-cluster/high-availability/recovering-a-primary-component).

## Backup SQL y ensayo de restore aislado

`backup.sh` usa dump consistente para tablas InnoDB del catálogo (`store`, nombre predeterminado), almacena gzip y SHA-256 en `backups/` ignorado por Git. Ejecutar diariamente durante el trabajo y antes de fallos destructivos; copiar cifrado a otro equipo. Replicación no reemplaza un backup. Evitar cambios DDL concurrentes durante el dump.

```bash
bash scripts/backup.sh galera2
ls -lh backups
```

Elegir el archivo correcto y restaurar en un contenedor aparte, sin puertos ni red del clúster:

```bash
BACKUP=backups/catalog-REEMPLAZAR.sql.gz
sha256sum -c "$BACKUP.sha256"
export RESTORE_PASSWORD=$(openssl rand -hex 24)
docker run -d --name lab-restore-check --network none \
 -e MARIADB_ROOT_PASSWORD="$RESTORE_PASSWORD" -e MARIADB_DATABASE=store mariadb:11.4
# Esperar hasta que este comando termine correctamente:
docker exec lab-restore-check sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-admin -uroot ping'
# Solo cuando esté listo:
gzip -dc "$BACKUP" | docker exec -i lab-restore-check sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot store'
docker exec lab-restore-check sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot store -e "SELECT COUNT(*) FROM products; SELECT sku,price FROM products ORDER BY sku;"'
# Tras guardar evidencia del restore, eliminar solo el contenedor desechable:
docker rm -fv lab-restore-check
unset RESTORE_PASSWORD
```

Comparar recuento y contenidos con el origen al momento del backup; registrar tiempo de restauración y fecha. No importar dumps directamente a los tres Galera a la vez. Para recuperación productiva: parar escrituras, restaurar en el clúster siguiendo un plan probado y comprobar replicación.

## Otras limitaciones operativas

MongoDB conserva datos en tres volúmenes; backup externo propio y pruebas de recuperación son trabajo adicional, no cubiertos por el dump SQL. No borrar esos volúmenes para cambiar el primary. Redis es desechable y no necesita recuperar valores: comprobar que el catálogo se reconstruye; los volúmenes de configuración sí guardan roles/topología.

La imagen Galera legacy del repositorio puede no estar disponible en el futuro. Si `pull` falla, guardar mensaje exacto y buscar una versión compatible con el profesor; no cambiar a `mariadb:latest` manteniendo variables Bitnami, porque sus scripts de arranque son diferentes. No se garantiza compatibilidad de los tags móviles de las demás imágenes: registrar digests de la ejecución real.

La interfaz administrativa del resilience-lab monta el socket Docker: queda ligada a `127.0.0.1` y no es necesaria para las pruebas remotas. Detener las herramientas al terminar:

```bash
docker compose -f resilience-lab/docker-compose.yml stop
```
