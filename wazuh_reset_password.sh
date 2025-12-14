#!/bin/bash

# =========================================================================
# SCRIPT DE RESTABLECIMIENTO DE CONTRASEÑA DE WAZUH DASHBOARD (admin)
# Creado para facilitar el proceso manual de cambio de credenciales de OpenSearch.
# =========================================================================

# -------------------------------------------------------------------------
# 1. CONFIGURACIÓN Y RUTAS CLAVE
# -------------------------------------------------------------------------

# Rutas comunes para los scripts de seguridad de OpenSearch/Wazuh Indexer
# El script buscará la primera ruta válida.
PATHS_TO_SEARCH=(
    "/usr/share/wazuh-indexer/plugins/opensearch-security/tools"
    "/usr/share/opensearch/plugins/opensearch-security/tools"
)

# Ruta del archivo de configuración de usuarios internos
INTERNAL_USERS_YML="/etc/opensearch/opensearch-security/internal_users.yml"

# Nombre del usuario a modificar (Generalmente 'admin')
TARGET_USER="admin"

# Variables para almacenar rutas encontradas
HASH_SCRIPT=""
ADMIN_SCRIPT=""
SECURITY_DIR=""


# -------------------------------------------------------------------------
# 2. FUNCIONES
# -------------------------------------------------------------------------

# Función para imprimir mensajes de error y salir
exit_on_error() {
    echo -e "\n\033[0;31m❌ ERROR: $1\033[0m"
    exit 1
}

# Función para encontrar los scripts y verificar la configuración
find_scripts() {
    echo -e "🔎 Buscando scripts de seguridad de OpenSearch..."
    for dir in "${PATHS_TO_SEARCH[@]}"; do
        if [ -d "$dir" ]; then
            if [ -x "$dir/hash.sh" ] && [ -x "$dir/securityadmin.sh" ]; then
                HASH_SCRIPT="$dir/hash.sh"
                ADMIN_SCRIPT="$dir/securityadmin.sh"
                SECURITY_DIR="/etc/opensearch/opensearch-security/"
                
                # Intentar encontrar la ruta de los certificados
                if [ ! -f "${SECURITY_DIR}/certs/root-ca.pem" ]; then
                    # Si no encuentra la ruta típica, buscar en /etc/wazuh-indexer/
                    SECURITY_DIR="/etc/wazuh-indexer/opensearch-security/"
                fi

                echo -e "✅ Scripts encontrados en: \033[0;32m$dir\033[0m"
                return 0
            fi
        fi
    done
    exit_on_error "No se pudieron encontrar los scripts 'hash.sh' y 'securityadmin.sh' en las rutas comunes. Verifica la instalación de Wazuh Indexer."
}

# Función para generar el hash de la nueva contraseña
generate_hash() {
    echo -e "\n=========================================================="
    echo -e "🔑 INGRESA LA NUEVA CONTRASEÑA para el usuario '$TARGET_USER'."
    echo "=========================================================="

    # Lectura de la contraseña en modo silencioso (no visible)
    read -s -p "Nueva Contraseña: " NEW_PASSWORD
    echo "" # Salto de línea después de la entrada silenciosa

    if [ -z "$NEW_PASSWORD" ]; then
        exit_on_error "La contraseña no puede estar vacía. Abortando."
    fi

    echo "Generando hash..."
    # Ejecuta el script hash.sh
    HASH_OUTPUT=$("$HASH_SCRIPT" -p "$NEW_PASSWORD")

    # Verifica si la generación del hash fue exitosa
    if [ $? -ne 0 ]; then
        exit_on_error "Fallo al generar el hash. Verifica que la contraseña no contenga caracteres inválidos o problemas de permisos."
    fi

    echo -e "\n✅ Hash generado: \033[0;33m$HASH_OUTPUT\033[0m"
    
    # Guardar el hash para usarlo globalmente
    NEW_HASH="$HASH_OUTPUT"
}

# Función para inyectar el nuevo hash en el archivo de configuración
update_yml() {
    echo -e "\n⏳ Actualizando el archivo de configuración $INTERNAL_USERS_YML..."
    
    if [ ! -f "$INTERNAL_USERS_YML" ]; then
        exit_on_error "Archivo $INTERNAL_USERS_YML no encontrado. Verifica la ruta o la instalación de OpenSearch."
    fi

    # Guardamos la configuración original como respaldo
    sudo cp "$INTERNAL_USERS_YML" "$INTERNAL_USERS_YML.bak.$(date +%Y%m%d%H%M%S)"

    # Utilizamos Perl para una sustitución multilínea más robusta:
    # 1. Busca la línea que comienza con 'admin:'
    # 2. Reemplaza la siguiente línea que contiene 'hash:' con el nuevo hash.
    sudo perl -i -pe "s/(^  ${TARGET_USER}:\n\s+hash: ).*/\1${NEW_HASH}/m" "$INTERNAL_USERS_YML"

    if [ $? -ne 0 ]; then
         exit_on_error "Fallo al modificar $INTERNAL_USERS_YML con el nuevo hash. Revisa el archivo de respaldo."
    fi

    echo -e "✅ Hash actualizado correctamente en $INTERNAL_USERS_YML."
}

# Función para aplicar la configuración de seguridad
apply_security_config() {
    echo -e "\n⏳ Aplicando la nueva configuración de seguridad con securityadmin.sh..."
    
    # Las rutas de los certificados son cruciales y a menudo están en /etc/opensearch/certs/ o /etc/wazuh-indexer/certs/
    CERT_DIR=$(dirname "$SECURITY_DIR")/certs
    
    if [ ! -d "$CERT_DIR" ]; then
        exit_on_error "Directorio de certificados no encontrado en $CERT_DIR. Las rutas pueden ser incorrectas."
    fi

    # Comando completo para aplicar los cambios de seguridad
    sudo "$ADMIN_SCRIPT" -cd "$SECURITY_DIR" -nhnv \
        -cacert "$CERT_DIR/root-ca.pem" \
        -cert "$CERT_DIR/admin.pem" \
        -key "$CERT_DIR/admin-key.pem"
        
    if [ $? -ne 0 ]; then
        exit_on_error "Fallo al ejecutar securityadmin.sh. Verifica las rutas de los certificados o si OpenSearch está en funcionamiento."
    fi
    
    echo -e "✅ Configuración de seguridad aplicada exitosamente."
}

# Función para reiniciar los servicios
restart_services() {
    echo -e "\n⏳ Reiniciando servicios de Wazuh Indexer y Dashboard para aplicar el cambio..."
    
    # Reiniciar Indexer
    sudo systemctl restart wazuh-indexer || sudo systemctl restart opensearch
    
    # Reiniciar Dashboard
    sudo systemctl restart wazuh-dashboard || sudo systemctl restart kibana
    
    echo -e "✅ Servicios reiniciados."
}


# -------------------------------------------------------------------------
# 3. EJECUCIÓN PRINCIPAL
# -------------------------------------------------------------------------

echo "=========================================================="
echo "         Wazuh Dashboard Password Reset Tool"
echo "=========================================================="

# 1. Verificar si se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
    exit_on_error "Este script debe ejecutarse con 'sudo'. Por favor, inténtalo de nuevo con: sudo ./wazuh_reset_password.sh"
fi

# 2. Encontrar rutas
find_scripts

# 3. Generar nuevo hash
generate_hash

# 4. Inyectar hash en YML (se hace con sudo dentro de la función)
update_yml

# 5. Aplicar la nueva configuración de seguridad (se hace con sudo)
apply_security_config

# 6. Reiniciar servicios (se hace con sudo)
restart_services

echo -e "\n\033[0;32m🎉 ¡PROCESO TERMINADO! 🎉\033[0m"
echo "La contraseña del usuario '$TARGET_USER' ha sido restablecida."
echo "Ahora puedes iniciar sesión en el Dashboard de Wazuh."
echo "=========================================================="
