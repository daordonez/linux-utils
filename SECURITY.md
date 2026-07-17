# Política de seguridad

## Notificación de vulnerabilidades

No publiques vulnerabilidades ni credenciales en incidencias, solicitudes de
extracción o discusiones públicas. Comunícalas de forma privada al propietario
del repositorio mediante GitHub.

## Secretos

No incluyas credenciales, tokens de API, claves privadas, certificados ni
archivos `.env` locales. Los valores de ejecución deben permanecer en los
archivos `.env` locales creados por los scripts de despliegue. El repositorio
analiza las solicitudes de extracción y los cambios en `main` para detectar
secretos expuestos.
