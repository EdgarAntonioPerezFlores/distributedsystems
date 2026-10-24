# Validación de esta entrega

## Comprobado en el entorno de preparación

- Descarga y revisión del upstream: commit `cf8f9f9046602ec294d4abb2477db979122efda4`.
- Fork existente `EdgarAntonioPerezFlores/distributedsystems`, mismo punto de partida que upstream.
- Parseo YAML, referencias de servicios/dependencias/redes, archivos montados y variables de `.env.example`.
- Sintaxis Node.js de API/clientes/init, sintaxis Bash y Python.
- Prueba unitaria del filtro Galera: acepta Primary/Synced/Ready/Connected; rechaza estados no elegibles o incompletos.
- Prueba unitaria con driver simulado: cambia de endpoint SQL en SELECT, limita reintentos y no repite escrituras automáticamente.
- XML del plan JMeter y revisión visual del JPG.

Comando reproducible (requiere Node.js y PyYAML en el equipo de desarrollo):

```bash
python3 scripts/validate-static.py
```

## Pendiente en el equipo de ejecución

Este entorno no dispone de Docker Engine ni acceso a la VM del estudiante. No se han ejecutado builds, descargado imágenes de runtime, iniciado Galera/MongoDB/Redis, probado VRRP ni medido rendimiento o fallos reales. El comportamiento bajo carga y la compatibilidad de las imágenes deben confirmarse con los runbooks; validación estática no equivale a un despliegue exitoso.

En Ubuntu:

```bash
docker compose config --quiet
bash scripts/first-start.sh   # solo si los volúmenes son nuevos
bash scripts/runtime-validate.sh
```

Después ejecutar `docs/PRUEBAS.md` desde ambos equipos y completar `docs/RESULTADOS.md`. Guardar salida exacta de cualquier error antes de cambiar configuración. No atribuir aprobaciones a estas pruebas pendientes.
