# Pasar el secreto inicial a GitOps cifrado
Preparar una clave age por entorno, guardar la privada en el gestor del equipo y una copia offline. Desde el administrador (umask 077):
```bash
age-keygen -o "$HOME/.config/sops/age/catalog-dev-key.txt"
age-keygen -y "$HOME/.config/sops/age/catalog-dev-key.txt"
kubectl -n flux-system create secret generic sops-age --from-file=age.agekey="$HOME/.config/sops/age/catalog-dev-key.txt"
```
Crear antes el directorio privado si no existe. Usar el destinatario público obtenido como AGE_RECIPIENT. Exportar el secret **directo a SOPS**, sin un YAML en claro en disco:
```bash
set -o pipefail
kubectl -n catalog get secret catalog-auth -o json | jq '{apiVersion,kind,metadata:{name:.metadata.name,namespace:.metadata.namespace},type,data}' | sops encrypt --age "$AGE_RECIPIENT" --encrypted-regex '^(data|stringData)$' --input-type json --output-type yaml /dev/stdin > deploy/platform/data/catalog.sops.yaml
```
Antes de añadirlo a Git confirmar que todos los valores bajo data empiezan por ENC[ y existe sops.mac. Añadir catalog.sops.yaml a deploy/platform/data/kustomization.yaml y en el objeto Kustomization llamado data de clusters/dev/stages.yaml añadir bajo spec: `decryption: {provider: sops, secretRef: {name: sops-age}}`. Revisar el diff y la reconciliación. No reemplazar contraseñas de una BD existente sin rotarlas dentro del servicio. Para producción utilizar otra clave y otra fuente de secretos; no incluir el secreto de dev en el overlay compartido de un clúster prod.
