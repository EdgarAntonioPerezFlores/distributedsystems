# Guía paso a paso: Ubuntu en VirtualBox y pruebas desde otra computadora

## 1. Qué corre en cada computadora

| Equipo | Responsabilidad |
|---|---|
| Tu computadora → VirtualBox → Ubuntu | Docker Engine, los 35 servicios de la solución, fallos controlados y evidencias del servidor |
| Computadora de tu compañero | Navegador, curl, ab/Siege o JMeter y registro de latencia/errores |
| GitHub | Código, configuración, diagrama y resultados revisados |

No hace falta que tu compañero levante otra copia del sistema. Debe apuntar las pruebas a **tu IP de Ubuntu**, nunca a `localhost`, a `galera1`, ni a las VIP internas `172.30.0.250`/`172.31.0.250`.

Suposición inicial: ambos están en la misma red local de confianza. Si están en casas distintas, ve al final de esta guía.

## 2. Preparar la VM

Presupuesto inicial orientativo: Ubuntu 24.04 de 64 bits, 4 CPU, 12 GB RAM y 50–60 GB libres. Ajustar tras medir; no es una capacidad garantizada. No asignes toda la RAM del anfitrión. Tres MongoDB y tres Galera pesan mucho más que un servidor web simple. En equipos de 8 GB totales, este laboratorio completo puede necesitar otra máquina o recursos adicionales.

Con la VM apagada: **Configuración → Red → Adaptador 1 → Adaptador puente**. Selecciona la tarjeta Wi-Fi/Ethernet que realmente usa tu computadora y deja «Cable conectado» marcado. Enciende Ubuntu y ejecuta:

```bash
ip -br addr
ip route
free -h
df -h /
lscpu
```

Busca una IP de la red local en `enp0s3` o similar, por ejemplo `192.168.1.80`. El ejemplo NO es tu IP real. No uses las direcciones de `docker0` ni de `br-*`. Si Ubuntu solo tiene `10.0.2.15`, probablemente sigue usando NAT. MongoDB moderno necesita las instrucciones de CPU apropiadas (AVX en x86_64); si muestra `Illegal instruction`, revisa CPU/virtualización antes de cambiar versiones.

## 3. Instalar Docker si no existe

Primero: `docker --version` y `docker compose version`. Si ya funcionan, conserva la instalación. Los comandos siguientes son para Ubuntu limpio; si hay `docker.io`/Compose antiguos, sigue la sección de conflictos de la documentación oficial antes de mezclar paquetes.

```bash
sudo apt update
sudo apt install -y ca-certificates curl git openssl unzip python3
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Cierra y vuelve a abrir tu sesión de Ubuntu para aplicar el grupo. Ese grupo permite administrar Docker con privilegios elevados; úsalo solo para la cuenta administradora de la VM.

```bash
docker run --rm hello-world
docker compose version
```

## 4. Obtener tu fork

Ya se identificó el fork `EdgarAntonioPerezFlores/distributedsystems`, cuyo padre es `tuxtter/distributedsystems`. Para continuar esta entrega se utiliza la rama principal `main`.

```bash
git clone --branch main https://github.com/EdgarAntonioPerezFlores/distributedsystems.git
cd distributedsystems
git remote add upstream https://github.com/tuxtter/distributedsystems.git
```

Si usas otra cuenta, abre el repositorio original, pulsa **Fork → Create fork**, y sustituye el dueño del repositorio al clonar. Descargar ZIP no crea un fork. Si recibes la entrega como ZIP, copia su contenido dentro del clon sin borrar `.git` y crea una rama antes de confirmar los cambios.

## 5. Primer arranque — solo para volúmenes nuevos

```bash
bash scripts/setup.sh
docker compose config --quiet
bash scripts/first-start.sh
bash scripts/verify.sh | tee results/baseline-servidor.txt
```

`setup.sh` crea contraseñas aleatorias y una clave compartida de MongoDB, sin subirlas a GitHub. `first-start.sh` descarga imágenes, construye aplicaciones, forma Galera, desactiva su bootstrap permanente y levanta el resto. Puede tardar varios minutos. Un `Exited (0)` de `mongo-init`/`catalog-init` es correcto: son trabajos de inicialización.

**No repitas `first-start.sh` sobre volúmenes existentes ni uses `down -v` para resolver errores.** El script se niega a arrancar sobre el volumen Galera existente. Recuperación: [OPERACION.md](OPERACION.md).

```bash
docker compose ps -a
docker compose logs --tail=100 galera1 galera2 galera3 mongo-init catalog-init app1
curl -i http://localhost/api/health/deep
curl -i http://localhost/api/products/cheapest
```

En Ubuntu abre `http://localhost`. Para Nagios usa `http://localhost:8088/nagios`, usuario `nagiosadmin`; consulta `NAGIOSADMIN_PASSWORD` en `.env` localmente, sin capturarlo en las evidencias.

## 6. Conectar a tu compañero

En el navegador de su computadora: `http://IP_DE_UBUNTU`. Por ejemplo, **solo si esa es tu IP**: `http://192.168.1.80`.

Linux/macOS/WSL:

```bash
curl -i --max-time 10 http://192.168.1.80/api/health
```

Windows PowerShell:

```powershell
Test-NetConnection 192.168.1.80 -Port 80
curl.exe -i http://192.168.1.80/api/health
```

Si falla: verifica IP actual, `curl http://localhost` dentro de Ubuntu, puente correcto, `docker compose ps`, puerto 80 ocupado (`sudo ss -lntp`) y aislamiento de clientes Wi-Fi. Una red de invitados/universitaria puede bloquear equipos entre sí; prueba una LAN de confianza por Ethernet. Un `ping` fallido por sí solo no demuestra que HTTP esté bloqueado.

Alternativa NAT: en VirtualBox configura un reenvío **TCP, IP anfitrión = IP LAN de tu computadora, puerto anfitrión 8080, IP invitado vacía, puerto invitado 80**. Tu compañero usa `http://IP_LAN_ANFITRION:8080`. Autoriza ese puerto en el firewall del anfitrión para su IP. No uses `127.0.0.1` como IP anfitrión si debe entrar otro equipo.

Se publica únicamente HTTP para las pruebas. Las bases de datos no publican puertos. Nagios y el dashboard quedan en loopback; no abras el dashboard que administra Docker a la LAN. Docker puede eludir reglas UFW para puertos publicados: no supongas que `ufw` por sí solo los restringe. Ejecuta este laboratorio en una red de confianza, sin reenvío en el router hacia Internet.

## 7. Prueba corta inicial de tu compañero

En Ubuntu/WSL de su equipo:

```bash
sudo apt update
sudo apt install -y apache2-utils siege curl git python3
git clone --branch main https://github.com/EdgarAntonioPerezFlores/distributedsystems.git
cd distributedsystems
export BASE=http://192.168.1.80   # cambiar por tu dirección real
python3 tests/functional.py "$BASE"
bash tests/load.sh "$BASE" 5 30
```

En una terminal de tu compañero, para registrar la caída y recuperación:

```bash
python3 tests/probe.py "$BASE" --seconds 180 --out results/failover-web1.csv
```

En otra terminal de su equipo:

```bash
bash tests/load.sh "$BASE" 20 180
```

Después de unos 30 segundos, **tú en Ubuntu servidor**, desde la carpeta del proyecto:

```bash
bash scripts/fault.sh stop web1 30
bash scripts/verify.sh
bash scripts/collect.sh
```

El script restaura el servicio al terminar. Las pruebas completas, fallos de bases de datos y cómo interpretar los resultados están en [PRUEBAS.md](PRUEBAS.md).

## 8. Subir documentación y resultados

Editen `docs/RESULTADOS.md`, agreguen nombres, recursos reales, IP utilizada y sus mediciones. Compartan resultados por archivos o GitHub; no compartan `.env`, claves ni copias de datos reales. `results/` está excluido de Git: publiquen una selección revisada en `docs/evidencias/`.

```bash
mkdir -p docs/evidencias
# Copiar aquí solo los reportes y capturas revisados, sin credenciales.
git add docs
git diff --cached
git commit -m "Documentar resultados reales de carga y failover"
git push origin main
```

Si `git push` pide autenticación, usa GitHub CLI (`gh auth login`) o una clave SSH configurada en tu cuenta. No uses la contraseña de GitHub como contraseña de Git ni pegues tokens en el repositorio.

## 9. Si están en redes distintas

El puente no hace accesible Ubuntu desde otra casa. Conecten ambos equipos con una VPN privada de laboratorio (por ejemplo, Tailscale/WireGuard), instalada en Ubuntu y en el equipo cliente; usen la IP de VPN de Ubuntu y autoricen solo HTTP entre ellos. La VPN agrega latencia: registren esa condición. No expongan Docker, MongoDB, Redis ni MariaDB al Internet público. También pueden reunirse en la misma LAN para que las mediciones sean más comparables.

Referencia de red: [Oracle VirtualBox 7.2](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/networkingdetails.html). Instalación y límites del firewall: [Docker en Ubuntu](https://docs.docker.com/engine/install/ubuntu/).
