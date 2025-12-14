# 🚀 USO DEL SCRIPT: `wazuh_reset_password.sh`

Este documento detalla cómo descargar, preparar y ejecutar el script `wazuh_reset_password.sh`, el cual automatiza el proceso de cambio de la contraseña del usuario `admin` del Wazuh Dashboard.

---

### ⚠️ Advertencia Importante

* **Servidor de Ejecución:** Este script **DEBE** ejecutarse en el servidor que aloja el componente **Wazuh Indexer** (donde residen los servicios de OpenSearch/Elasticsearch).
* **Permisos:** Requiere privilegios de `sudo` o `root` para modificar archivos de configuración del sistema y reiniciar servicios.
* **Tiempo de Inactividad:** La ejecución del script conlleva el reinicio del `wazuh-indexer` y `wazuh-dashboard`, lo que provocará una interrupción temporal de la plataforma que dependerá de la potencia de tu equipo.

---

### ➡️ Pasos para la Ejecución

Sigue este flujo de trabajo en tu servidor del Wazuh Indexer:

#### 1. ⚡️ Comandos de Ejecución Secuencial

Copia y pega el siguiente bloque de comandos en tu terminal. El script te pedirá la nueva contraseña de forma segura (sin mostrarla en pantalla).

```bash
# 1. Descarga el script desde el repositorio (rama main).
wget [https://raw.githubusercontent.com/zeroami/Wazuh-SOC-lab/main/wazuh_reset_password.sh](https://raw.githubusercontent.com/zeroami/Wazuh-SOC-lab/main/wazuh_reset_password.sh)

# 2. Otorga permisos de ejecución al archivo descargado.
chmod +x wazuh_reset_password.sh

# 3. Ejecuta el script con privilegios de administrador (sudo).
sudo ./wazuh_reset_password.sh
