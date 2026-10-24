# Error inicial: contraseña mayor de 32 caracteres

La imagen Galera usada rechaza MARIADB_ROOT_PASSWORD de más de 32 caracteres. El setup anterior generaba 48; se corrigió a 32.

Para el arranque que falló durante esta validación, ejecutar desde el repositorio:

```bash
git pull --ff-only origin main
bash scripts/repair-initial-passwords.sh
```

La reparación detiene los tres Galera, comprueba con montajes de solo lectura que ninguno de sus volúmenes contiene archivos, respalda .env dentro de secrets/ y acorta únicamente las tres contraseñas SQL generadas anteriormente. No imprime secretos ni borra volúmenes. Después reanuda el primer arranque. Si hay archivos, nodos activos o formato inesperado, se detiene; no sirve para rotar contraseñas en bases ya inicializadas.

Se verificaron la sintaxis Bash, generación de 32 caracteres, conservación de otras credenciales, respaldo, repetibilidad y rechazo sin modificación de formatos inesperados. La comprobación Docker y el arranque deben ejecutarse en Ubuntu.
