# Evidencias visuales de Nagios — 24 de octubre de 2026

Capturas aportadas desde la computadora de la colaboradora Windows, conectada a la instancia Nagios Core alojada en Ubuntu mediante túnel SSH. Las tres imágenes son archivos PNG originales; no deben confundirse los **estados de hosts** con los **estados de servicios**.

## Secuencia observada

| Evidencia | Hora indicada por Nagios (UTC) | Hosts UP | Hosts DOWN | Servicios OK | Servicios CRITICAL |
|---|---|---:|---:|---:|---:|
| Estado inicial | 22:08 | 24 | 0 | 30 | 0 |
| Un host detectado como DOWN | 22:38 | 23 | **1** | 30 | 0 |
| Recuperación observada | 22:41 | 24 | 0 | 30 | 0 |

### 1. Estado inicial — 24 hosts UP, 30 servicios OK

![Nagios: estado inicial](nagios-01-estado-inicial-20261024.png)

### 2. Detección — 23 hosts UP, 1 DOWN, 30 servicios OK

![Nagios: un host DOWN, con web1 resaltado](nagios-02-web1-down-20261024.png)

En la tabla está resaltado el host **web1**; el contador superior de Nagios indica un host **DOWN**. Los 30 servicios siguen en **OK** en esta captura, por lo que **no** hay evidencia de un servicio CRITICAL en ella.

### 3. Recuperación — 24 hosts UP, 30 servicios OK

![Nagios: 24 hosts UP, 30 servicios OK nuevamente](nagios-03-recuperacion-20261024.png)

## Correlación adicional con el log de Nagios (no visible en los PNG)

El registro activo `/opt/nagios/var/nagios.log` facilitado posteriormente **sí** incluye, para el ensayo que empezó a las **22:38:42 UTC**, `SERVICE ALERT: web1;Website HTTP;CRITICAL;HARD;1` a las **22:38:56 UTC**, `HOST ALERT: web1;DOWN;HARD;2` a las **22:39:30 UTC**, y `SERVICE ... OK;HARD` / `HOST ... UP;HARD` a las **22:40:56 UTC**. El host tuvo primer aviso `DOWN;SOFT` a las **22:38:48 UTC**.

La consola indicó restauración solicitada a las **22:40:45 UTC**. Por tanto, la detección del host SOFT ocurrió a **+6 s**, la alerta del servicio CRITICAL HARD a **+14 s**, el host DOWN HARD a **+48 s** y la recuperación reconocida por Nagios **11 s después de solicitarse**. Se trata de una sola observación, no de MTTD/MTTR promedios. [Tabla de eventos y explicación](../RESULTADOS.md#evidencia-correlacionada-de-nagios-y-fallo-real-de-web1-24-10-2026).

**No alterar la interpretación de las capturas:** sus contadores muestran **30 servicios OK**, y el estado **CRITICAL del servicio fue demostrado por los registros, no por esos PNG**. Los logs originales deben publicarse después de revisar que no contienen credenciales.

## Alcance y limitaciones

- La transición visual **24 UP → 23 UP / 1 DOWN → 24 UP** está respaldada por las tres capturas.
- Las horas mostradas por el panel son horas UTC, no necesariamente la hora local de la laptop.
- La correspondencia temporal **sí está acreditada por logs del fallo y Nagios recibidos después de estas capturas**; las imágenes por sí solas no bastaban. Se calcularon tiempos de **un ensayo**, no medias de múltiples ejecuciones.
- La captura de un host **DOWN** no significa que un servicio esté en estado **CRITICAL**: el resumen de servicios muestra 30 OK en las tres imágenes.
- Los tres archivos PNG originales **ya están publicados** en `docs/evidencias/` en la rama `main`, en el commit [`b685f277`](https://github.com/EdgarAntonioPerezFlores/distributedsystems/commit/b685f2771b54f6462f0c4f4cf49f48a645d26548). Los enlaces de las imágenes se muestran directamente en esta galería.

[Volver a resultados](../RESULTADOS.md).
