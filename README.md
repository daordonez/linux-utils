# linux-utils

Utilidades para administración de hosts Linux.

## Aplicaciones Docker

Instala y muestra el menú de aplicaciones sin clonar el repositorio:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/daordonez/linux-utils/main/install.sh)
```

Instala todas las aplicaciones:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/daordonez/linux-utils/main/install.sh) --all
```

El instalador descarga una copia temporal del repositorio y la elimina al terminar. Las aplicaciones que requieren secretos solicitan los valores en la terminal; no uses `curl ... | sh`.

Cada despliegue elimina previamente los contenedores, redes y volúmenes del proyecto Compose, descarga las imágenes y recrea la aplicación. Los datos persistentes de la aplicación se eliminan en cada ejecución.

El instalador principal crea `~/containers`, una carpeta por servicio y el registro `~/containers/linux_utils.log`. El registro incluye fecha, nivel, salida de Docker Compose, estado final de los contenedores e ID de la imagen desplegada.

Para instalar una versión concreta, sustituye `main` por una etiqueta publicada tanto en la URL como en `LINUX_UTILS_REF`:

```bash
LINUX_UTILS_REF=v1.0.0 bash <(curl -fsSL https://raw.githubusercontent.com/daordonez/linux-utils/v1.0.0/install.sh) --all
```

Opcionalmente, define `LINUX_UTILS_SHA256` para validar el archivo descargado con `sha256sum`.

Desde un clon local:

```bash
./docker/deploy_apps.sh
./docker/deploy_apps.sh --all
```
