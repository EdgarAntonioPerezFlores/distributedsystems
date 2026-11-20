# Migración del catálogo a K3s — entrega 30 de noviembre
Base: `f018537` (congelada en `segundo-parcial`). La rama `proyecto-ha-virtualbox` conserva el ensayo de web1; el informe de main ya registra sus 144/145 muestras y la correlación temporal. No mezclar el Compose del parcial 2 con los archivos de este despliegue. Los cambios sin commit dentro de las VMs no son visibles en GitHub: revisar allí `git status -sb`, `git log --oneline --all -8` y `git stash list` antes de cambiar de rama.

## Diseño e implementación
Tres servidores Ubuntu con K3s/etcd; MetalLB asigna una IP LAN a Traefik. Traefik termina TLS y entrega a tres Nginx; /api pasa al Service api. La API consulta Galera vía MaxScale, MongoDB con SCRAM y Redis con Sentinel. Las escrituras de reseñas en K3s devuelven 202 tras confirmación del broker. El worker escribe por clave de idempotencia y reintenta tras 5 s; después de tres reintentos el mensaje pasa a la DLQ. catalog.changed invalida la caché y catalog.refresh la precarga con un consumidor. Compose conserva escritura directa si AMQP_URL no está definida. Los datos y volúmenes de Compose no se importan al instalar; el Job sólo carga el catálogo de muestra. Ver [plan original](../PLATFORM-MIGRATION-PLAN.md).

| Fase | Archivos y alcance | Validación pendiente en el equipo |
|---|---|---|
| 0–2 | Dockerfiles sin root, healthz/readyz, Terraform sobre tres Ubuntu existentes, Flux, overlays, HPA/PDB, distribución de pods y operadores. Local-path queda ligado al nodo. | Probar quórum y recuperación con un host físico caído, PVC y capacidad de cada VM. |
| 3 | Colas quorum persistentes, confirmación del publicador, reintentos y DLQ. Un worker para evitar lecturas SQL concurrentes al recalentar. | Verificar doble POST, reinicio del consumidor, backlog y DLQ. |
| 4–5 | CI valida código, imágenes e IaC. Release publica GHCR con SHA, SBOM y firma; actualiza el overlay dev. Flux ordena operadores → datos/colas → apps. | Ejecutar CI, configurar permisos GHCR, protección de ramas/aprobación y notificaciones. Para prod promover el SHA probado mediante PR a release; no desplegar candidate. |
| 6 | SDK Node, colector con k8sattributes, agente de logs y LGTM compacto de laboratorio sin persistencia. | Verificar una traza HTTP/AMQP, métricas y logs en Grafana. Faltan instrumentación navegador/Nginx, dashboards, alertas y persistencia antes de producción. |
| 7 | TLS de laboratorio, auditoría de K3s, roles de BD, FS de sólo lectura en pods de app, políticas de entrada web/API, Wazuh con credenciales aleatorias. | Probar agentes e ingestión, añadir políticas de salida/datos, SOPS para secretos declarativos, autenticación/rate limit, Kyverno y CIS. |
| 8 | Scripts comparables y procedimientos de reversión. | Ejecutar carga, ensayos de fallo, restauración y cambio gradual de tráfico. Mantener Compose hasta entonces. |

[Aceptación, caos y restauración](VALIDACION-K3S.md) · [Secretos con SOPS y age](SECRETOS-K3S.md).

## Instalación en VirtualBox
1. En cada computadora del equipo crear al menos un nodo del clúster. Para tres integrantes: una VM Ubuntu por computadora. Con dos equipos, una VM en cada uno y una tercera VM adicional: si dos servidores comparten host, perder ese host pierde la mayoría etcd; confirmar con el docente si exige tres equipos físicos. Usar adaptador **puente**, IPv4 estables en la misma LAN, hora sincronizada y una VIP libre fuera de DHCP. Una red sólo-anfitrión no comunica computadoras distintas. Registrar PC→VM→IP y recursos reales. Usar Ubuntu con CPU compatible con MongoDB y espacio para imágenes, volúmenes y logs; vigilar RAM con los operadores y Wazuh.
2. Desde el equipo administrador preparar Git, SSH por llave con host keys verificadas y sudo sin contraseña en las VMs dedicadas; instalar Terraform >=1.10, kubectl, Flux CLI, curl, openssl, python3 y apache2-utils. Permitir entre nodos API 6443/TCP, etcd 2379–2380/TCP, kubelet 10250/TCP, Flannel 8472/UDP y speakers 7946/TCP+UDP sólo en la LAN del laboratorio. No usar la VM Compose existente como servidor nuevo. Usar una deploy key SSH con escritura para Flux y un backend S3 privado con versionado y bloqueo, por entorno.
3. En una copia nueva del fork:
   ```bash
   git clone --branch migracion-k3s https://github.com/EdgarAntonioPerezFlores/distributedsystems.git catalog-k3s
   cd catalog-k3s/infra/terraform
   cp lab.tfvars.example lab.tfvars
   # Editar IP, usuario y rutas. Exportar TF_STATE_BUCKET y AWS_REGION del backend.
   terraform init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="region=$AWS_REGION" -backend-config="key=catalog/terraform.tfstate" -backend-config="use_lockfile=true"
   terraform workspace select -or-create dev
   terraform apply -target=module.storage -var-file=lab.tfvars
   terraform plan -var-file=lab.tfvars -out=lab.tfplan
   terraform apply lab.tfplan
   cd ../..
   export KUBECONFIG="$HOME/.kube/catalog-dev"
   kubectl get nodes -o wide
   flux get helmreleases -A
   ```
   El primer apply separado crea el kubeconfig antes de que el proveedor Flux lo lea. Terraform configura VMs existentes; no crea ni borra máquinas en las computadoras. Para producción usar workspace y cluster independientes y rama protegida release. El endpoint administrativo inicial usa la primera IP; para operar si ese servidor cae, utilizar el kubeconfig del servidor superviviente o un balanceador de API dedicado.
4. Publicar imágenes desde el workflow **Publish lab images** en esta rama (si las políticas de GitHub sólo permiten disparar manualmente workflows de la rama predeterminada, integrar primero el workflow revisado). Permitir paquetes públicos para el laboratorio o configurar imagePullSecrets. Confirmar que los dos newTag de dev dicen sha-… y existen en GHCR. Si la publicación no pudo escribir en Git, actualizar esos newTag al SHA publicado por PR. Para bootstrap **no usar main** mientras main siga siendo Compose.
5. Una vez disponibles cert-manager y MetalLB:
   ```bash
   export LAB_VIP=192.168.1.240   # sustituir por la IP reservada
   bash scripts/k3s-prepare.sh
   flux get kustomizations -A
   kubectl -n catalog get pods,pvc,hpa,pdb,ingress -o wide
   kubectl -n catalog wait --for=condition=complete job/catalog-seed-v1 --timeout=10m
   kubectl -n catalog get secret catalog-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/catalog-lab.crt
   ```
   Agregar VIP y catalog.lab.test al DNS o /etc/hosts del cliente. Exportar `CURL_CA_BUNDLE=/tmp/catalog-lab.crt` en ese cliente (transferir sólo el certificado público). Abrir https://catalog.lab.test. Si el clúster no converge, consultar `flux logs --all-namespaces --level=error`, pods y eventos; comprobar imágenes Redis legacy y no sustituir versiones sin prueba.
6. Wazuh en nodos con capacidad suficiente: instalar python3-yaml y python3-bcrypt en el administrador; ejecutar `bash scripts/k3s-wazuh.sh` una sola vez. Construir la imagen con `docker build -f deploy/platform/wazuh/agent.Dockerfile -t ghcr.io/edgarantonioperezflores/distributedsystems-wazuh-agent:lab .`, publicarla con docker push y ejecutar `kubectl apply -f deploy/platform/wazuh/agent.yaml`. Verificar un agente por nodo y un evento de auditoría en el dashboard. Los servicios quedan internos; usar port-forward. Guardar copias cifradas de certificados, configuración y secretos antes de cualquier reinstalación.

## Evidencias y aceptación
Desde el mismo cliente y en las mismas condiciones registrar topología física, SHA de imágenes, versiones, CPU/RAM, ruta y caché. Ejecutar:
```bash
export BASE_URL=https://catalog.lab.test PLATFORM=k3s
bash scripts/k3s-review-test.sh
bash scripts/k3s-performance.sh
```
El script guarda AB completo, CSV, salud posterior, nodos, pods y uso de recursos en results/. Conservar el informe incluso si se incumple el umbral. Revisar que dure 600 s, p95 <200 ms, cero fallos AB y cero no-2xx. Para comparar desde la misma máquina repetir con PLATFORM=compose y la URL LAN anterior. Copiar los resultados revisados (sin credenciales) a docs/evidencias/k3s/ en un commit.

| Plataforma y cliente | c / duración | Solicitudes | Req/s | p95 / p99 | Evidencia |
|---|---:|---:|---:|---:|---|
| Compose anterior, cliente en la VM | 20 / 600.002 s | 302663 | 504.44 | 87 / 134 ms | [Medición histórica; AB reportó cero fallidas](RESULTADOS.md) |
| K3s, cliente de la LAN | 20 / 600 s previstos | — | — | — | Pendiente de ejecución en las computadoras del equipo. |

Para el failover, mantener una sonda externa, registrar UTC antes y después de retirar **un** pod web, comprobar réplicas Ready, HTTP y tiempo de recuperación; repetir por separado para un servidor sólo después de verificar tres miembros sanos. No declarar HA de host con tres VMs en la misma PC. Mantener Nagios en el equipo externo apuntando a la VIP y registrar HTTP, certificado y API. En Grafana (port-forward svc/lgtm 3000:3000 -n observability) revisar errores, latencia y saturación. Si crece la cola, comprobar worker, Mongo y DLQ antes de reintentar; no purgar mensajes para ocultar errores.

**Corte y reversión:** tomar backups de datos y definiciones, ensayar restauración en un namespace aislado, detener escrituras o establecer sincronización antes de repartir tráfico entre plataformas. Probar primero con hosts/DNS de laboratorio. Ante degradación, volver DNS a Compose, conservar los volúmenes y conciliar las reseñas aceptadas después del corte. Para código, revertir en Git el cambio de imagen, esperar la reconciliación y verificar /api/health/deep y una reseña. No ejecutar docker compose down -v ni terraform destroy como rollback. Ante alerta de seguridad preservar auditoría, limitar acceso al componente afectado y rotar el secreto comprometido.
