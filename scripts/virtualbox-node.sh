#!/usr/bin/env bash
# Execute on each physical Linux host. Creates a fresh VM; refuses to replace one.
set -euo pipefail
: "${VM_NAME:?catalog-0, catalog-1 o catalog-2}" "${BRIDGE:?interfaz física}" "${BASE_VDI:?VDI Ubuntu cloud con cloud-init}" "${ADMIN_PUBKEY:?ruta a clave pública}"
[[ "$VM_NAME" =~ ^catalog-[012]$ ]] && test -f "$BASE_VDI" && test -f "$ADMIN_PUBKEY"
if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then echo "La VM ya existe" >&2; exit 1; fi
folder="${VM_ROOT:-$HOME/VirtualBox VMs}/$VM_NAME"
[[ ! -e "$folder" ]]
VBoxManage createvm --name "$VM_NAME" --ostype Ubuntu_64 --basefolder "$(dirname "$folder")" --register
key=$(cat "$ADMIN_PUBKEY")
cat > "$folder/user-data" <<USERDATA
#cloud-config
hostname: $VM_NAME
users:
- name: alumno
  groups: [sudo]
  shell: /bin/bash
  sudo: ALL=(ALL) NOPASSWD:ALL
  ssh_authorized_keys:
  - $key
ssh_pwauth: false
USERDATA
echo "instance-id: $VM_NAME" > "$folder/meta-data"
cloud-localds "$folder/seed.iso" "$folder/user-data" "$folder/meta-data"
VBoxManage clonemedium disk "$BASE_VDI" "$folder/node.vdi" --format VDI
VBoxManage modifymedium disk "$folder/node.vdi" --resize "${VM_DISK_MB:-51200}"
VBoxManage modifyvm "$VM_NAME" --memory "${VM_RAM_MB:-8192}" --cpus "${VM_CPUS:-4}" --nic1 bridged --bridgeadapter1 "$BRIDGE" --cableconnected1 on
VBoxManage storagectl "$VM_NAME" --name SATA --add sata --controller IntelAhci
VBoxManage storageattach "$VM_NAME" --storagectl SATA --port 0 --device 0 --type hdd --medium "$folder/node.vdi"
VBoxManage storageattach "$VM_NAME" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$folder/seed.iso"
VBoxManage startvm "$VM_NAME" --type headless
echo "Reservar IPv4 por DHCP; verificar la huella SSH en la consola del nuevo nodo."
