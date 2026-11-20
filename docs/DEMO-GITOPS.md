# Demostración: desplegar un cambio aprobado y revertirlo desde Git
El objetivo es mostrar que un cambio en main llega a los pods sin ejecutar kubectl apply desde la computadora de Edgar o Ana. El ejemplo modifica únicamente la marca de entrega del pod web en dev. Al cambiar la plantilla de pods, Kubernetes reemplaza gradualmente las réplicas. No hace falta recompilar la imagen para cambiar esta marca.

## Antes de la clase
Preparar las VMs con la [guía de instalación](MIGRACION-K3S.md). Terraform configura los nodos y arranca Flux: versions.tf declara versiones y backend, providers.tf configura Flux, variables.tf valida entradas y main.tf conecta los módulos network, k3s-nodes, storage y flux-bootstrap. El estado de dev y prod se administra por separado. No subir .tfvars con datos privados ni estados.

K3s incluye Traefik: MetalLB entrega la IP de la LAN y Traefik recibe el tráfico HTTPS. La ruta del usuario es Traefik → Service web → Nginx; Nginx pasa /api al Service api. Para la demostración no se inicia HAProxy ni Keepalived. El Compose antiguo queda como referencia del segundo parcial.

## Ensayo en dev
1. En el administrador seleccionar el kubeconfig de dev. Ejecutar desde la LAN:
   ```bash
   flux get sources git -n flux-system
   flux get kustomizations -n flux-system
   kubectl -n catalog get ingress catalog
   kubectl -n catalog get pods -l app=web -o 'custom-columns=POD:.metadata.name,ENTREGA:.metadata.annotations.laboratorio\.unicaribe/entrega'
   curl -fsS https://catalog.lab.test/api/health/deep
   ```
   Usar el certificado del laboratorio según la guía. Confirmar apps Ready, clase traefik y réplicas web con v1 antes de continuar.
2. En GitHub, editar deploy/overlays/dev/web-entrega.yaml: cambiar sólo v1 por v2. Abrir un PR hacia main. Mostrar **Platform CI**, que entre otras comprobaciones valida Terraform y renderiza ambos entornos. Si pasa, integrar el PR. Guardar el SHA integrado.
3. Esperar la sincronización automática o adelantarla con `flux reconcile kustomization apps -n flux-system --with-source`. Revisar `flux get kustomizations -n flux-system` y comparar la revisión aplicada con main. Ejecutar `kubectl -n catalog rollout status deployment/web --timeout=5m` y repetir los comandos de pods y salud del paso 1. Se esperan nombres nuevos, marca v2 y respuesta saludable por HTTPS.
4. Revertir el PR en GitHub e integrar la reversión. Repetir el paso 3 y verificar que los pods vuelven a v1. Guardar los dos SHA, las salidas y las horas. Una verificación que no se haya ejecutado en las VMs debe quedar como pendiente.

Para un cambio de código en web o API hay un paso adicional: release.yml construye y firma las imágenes, las publica en GHCR y actualiza en Git las etiquetas del overlay dev. Flux lee ese commit y Kubernetes despliega la revisión. GitHub Actions no necesita el kubeconfig para publicar esas imágenes. Para un cambio de manifiesto como el del ensayo, Flux aplica directamente el cambio aprobado.
