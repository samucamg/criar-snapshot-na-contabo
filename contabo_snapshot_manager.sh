#!/bin/bash

# --- Configurações Iniciais ---
set -o errexit  # Sair imediatamente se um comando sair com status diferente de zero
set -o pipefail # O status de saída de um pipeline é o do último comando que falhou
# set -o nounset # Tratar variáveis não definidas como erro (opcional, mas bom para debugging)

# --- Variáveis Globais ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
CONFIG_FILE="$SCRIPT_DIR/config.conf"
LOG_FILE="$SCRIPT_DIR/contabo_snapshot.log"
TIMESTAMP_EXEC=$(date +"%Y-%m-%d %H:%M:%S")
TIMESTAMP_SNAP=$(date +%Y%m%d-%H%M%S) # Para nomear o snapshot

# --- Funções Auxiliares ---
log_message() {
    echo "[$TIMESTAMP_EXEC] $1" | tee -a "$LOG_FILE"
}

check_dependencies() {
    local missing_deps=0
    for cmd in curl jq uuidgen; do
        if ! command -v "$cmd" &> /dev/null; then
            log_message "ERRO: Dependência '$cmd' não encontrada. Por favor, instale-a."
            missing_deps=1
        fi
    done
    if [ "$missing_deps" -eq 1 ]; then
        exit 1
    fi
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERRO: Arquivo de configuração '$CONFIG_FILE' não encontrado."
        exit 1
    fi
    source "$CONFIG_FILE"

    local essential_vars=(CLIENT_ID CLIENT_SECRET API_USER API_PASSWORD URL_EVOLUTION APIKEY_EVOLUTION INSTANCE_EVOLUTION WHATSAPP_RECIPIENT_JID)
    for var in "${essential_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_message "ERRO: Variável '$var' não definida no arquivo de configuração."
            exit 1
        fi
    done
}

get_contabo_token() {
    local token_response
    token_response=$(curl -s -X POST 'https://auth.contabo.com/auth/realms/contabo/protocol/openid-connect/token' \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d "client_id=$CLIENT_ID" \
        -d "client_secret=$CLIENT_SECRET" \
        --data-urlencode "username=$API_USER" \
        --data-urlencode "password=$API_PASSWORD" \
        -d 'grant_type=password')

    ACCESS_TOKEN=$(echo "$token_response" | jq -r '.access_token')

    if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
        log_message "ERRO: Falha ao obter o token de acesso da Contabo."
        log_message "Resposta: $token_response"
        # Não saia aqui, tentaremos enviar a notificação de erro
        send_whatsapp_notification "Detalhe dos seus Backups na Contabo (${TIMESTAMP_EXEC}):\n\nERRO CRÍTICO: Falha ao obter o token de acesso da Contabo. Verifique as credenciais e a conectividade.\nStatus da operação: Falha ao iniciar."
        exit 1
    fi
    log_message "Token de acesso da Contabo obtido com sucesso."
}

send_whatsapp_notification() {
    local message_text="$1"
    local evolution_url="${URL_EVOLUTION}/message/sendText/${INSTANCE_EVOLUTION}"

    log_message "Enviando notificação para WhatsApp: ${WHATSAPP_RECIPIENT_JID}"
    # Escapar quebras de linha para JSON
    local json_safe_message_text=$(echo "$message_text" | sed ':a;N;$!ba;s/\n/\\n/g')


    local response
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$evolution_url" \
        -H "Content-Type: application/json" \
        -H "apikey: ${APIKEY_EVOLUTION}" \
        -d @- <<EOF
{
    "number": "${WHATSAPP_RECIPIENT_JID}",
    "options": {
      "delay": 1200,
      "presence": "composing"
    },
    "textMessage": {
      "text": "${json_safe_message_text}"
    }
}
EOF
)
    local http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d':' -f2)

    if [ "$http_status" == "201" ] || [ "$http_status" == "200" ]; then
        log_message "Notificação do WhatsApp enviada com sucesso."
    else
        log_message "ERRO: Falha ao enviar notificação do WhatsApp. Status: $http_status"
        log_message "Resposta da Evolution API: $(echo "$response" | sed '$d')"
    fi
}

# --- Função Principal ---
main() {
    check_dependencies
    load_config
    # Inicializar as seções do relatório
    local deleted_snapshots_summary="Foram deletados os seguintes Backups:\n"
    local created_snapshots_summary="Foram criados os seguintes Backups:\n"
    local error_messages_summary="Mensagens de erro:\n"
    local overall_status="Sucesso"
    local vps_details_summary="" # Para detalhes por VPS

    get_contabo_token # Token é necessário para continuar

    local TRACE_ID
    TRACE_ID=$(uuidgen)

    log_message "Iniciando processo de gerenciamento de snapshots."

    local UUID_REQ_INSTANCES=$(uuidgen)
    local instances_json
    instances_json=$(curl -s -X GET "https://api.contabo.com/v1/compute/instances" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "x-request-id: ${UUID_REQ_INSTANCES}" \
        -H "x-trace-id: ${TRACE_ID}")

    if ! echo "$instances_json" | jq -e '.data' &> /dev/null; then
        log_message "ERRO: Falha ao obter a lista de instâncias. Resposta: $instances_json"
        error_messages_summary+="  - Falha ao obter a lista de instâncias da Contabo.\n"
        overall_status="Erro"
    else
        local instance_ids
        mapfile -t instance_ids < <(echo "$instances_json" | jq -r '.data[].instanceId')

        if [ ${#instance_ids[@]} -eq 0 ]; then
            log_message "Nenhuma instância encontrada."
            vps_details_summary+="Nenhuma instância encontrada para processar.\n"
        else
            log_message "Instâncias encontradas: ${instance_ids[*]}"

            for instance_id in "${instance_ids[@]}"; do
                log_message "Processando instância ID: $instance_id"
                vps_details_summary+="\nVPS ID: $instance_id\n"
                local UUID_REQ
                local instance_has_errors=0

                # 1. Listar snapshots e encontrar o mais antigo
                UUID_REQ=$(uuidgen)
                local snapshots_json
                snapshots_json=$(curl -s -X GET "https://api.contabo.com/v1/compute/instances/${instance_id}/snapshots" \
                    -H 'Content-Type: application/json' \
                    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
                    -H "x-request-id: ${UUID_REQ}" \
                    -H "x-trace-id: ${TRACE_ID}")

                if ! echo "$snapshots_json" | jq -e '.data' &> /dev/null; then
                    log_message "ERRO: Falha ao listar snapshots para a instância $instance_id. Resposta: $snapshots_json"
                    vps_details_summary+="  - Erro ao listar snapshots.\n"
                    error_messages_summary+="  - Erro ao listar snapshots para VPS ID $instance_id.\n"
                    overall_status="Erro"
                    instance_has_errors=1
                else
                    local oldest_snapshot_id
                    oldest_snapshot_id=$(echo "$snapshots_json" | jq -r '.data | sort_by(.createdDate) | .[0].snapshotId // empty')

                    if [ -n "$oldest_snapshot_id" ]; then
                        log_message "Snapshot mais antigo encontrado para instância $instance_id: $oldest_snapshot_id"
                        UUID_REQ=$(uuidgen)
                        local delete_response_status
                        delete_response_status=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "https://api.contabo.com/v1/compute/instances/${instance_id}/snapshots/${oldest_snapshot_id}" \
                            -H 'Content-Type: application/json' \
                            -H "Authorization: Bearer ${ACCESS_TOKEN}" \
                            -H "x-request-id: ${UUID_REQ}" \
                            -H "x-trace-id: ${TRACE_ID}" \
                            -d '{}')

                        if [ "$delete_response_status" == "204" ]; then
                            log_message "Snapshot $oldest_snapshot_id deletado com sucesso da instância $instance_id."
                            deleted_snapshots_summary+="  - $oldest_snapshot_id (VPS: $instance_id)\n"
                            vps_details_summary+="  - Snapshot antigo ($oldest_snapshot_id) deletado.\n"
                        else
                            log_message "ERRO: Falha ao deletar o snapshot $oldest_snapshot_id da instância $instance_id. Status: $delete_response_status"
                            vps_details_summary+="  - Erro ao deletar snapshot $oldest_snapshot_id (Status: $delete_response_status).\n"
                            error_messages_summary+="  - Erro ao deletar snapshot $oldest_snapshot_id (VPS: $instance_id, Status: $delete_response_status).\n"
                            overall_status="Erro"
                            instance_has_errors=1
                        fi
                    else
                        log_message "Nenhum snapshot encontrado para deletar na instância $instance_id."
                        vps_details_summary+="  - Nenhum snapshot antigo para deletar.\n"
                    fi
                fi # Fim da verificação de erro ao listar snapshots

                # 2. Criar um novo snapshot (mesmo se a deleção falhou, tentamos criar)
                local new_snapshot_name="snap-${TIMESTAMP_SNAP}"
                local new_snapshot_description="Backup automatico diario - ${TIMESTAMP_EXEC}"
                log_message "Criando novo snapshot '$new_snapshot_name' para a instância $instance_id..."
                UUID_REQ=$(uuidgen)

                local create_response
                create_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "https://api.contabo.com/v1/compute/instances/${instance_id}/snapshots" \
                    -H 'Content-Type: application/json' \
                    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
                    -H "x-request-id: ${UUID_REQ}" \
                    -H "x-trace-id: ${TRACE_ID}" \
                    -d "{\"name\":\"${new_snapshot_name}\",\"description\":\"${new_snapshot_description}\"}")

                local create_http_status=$(echo "$create_response" | grep "HTTP_STATUS:" | cut -d':' -f2)
                local create_response_body=$(echo "$create_response" | sed '$d')

                if [ "$create_http_status" == "201" ]; then
                    local new_snapshot_id=$(echo "$create_response_body" | jq -r '.data[0].snapshotId')
                    log_message "Novo snapshot '$new_snapshot_name' (ID: $new_snapshot_id) criado com sucesso para a instância $instance_id."
                    created_snapshots_summary+="  - $new_snapshot_name (ID: $new_snapshot_id, VPS: $instance_id)\n"
                    vps_details_summary+="  - Novo snapshot '$new_snapshot_name' (ID: $new_snapshot_id) criado.\n"
                else
                    log_message "ERRO: Falha ao criar novo snapshot para a instância $instance_id. Status: $create_http_status"
                    log_message "Resposta da API: $create_response_body"
                    vps_details_summary+="  - Erro ao criar novo snapshot (Status: $create_http_status).\n"
                    error_messages_summary+="  - Erro ao criar novo snapshot para VPS $instance_id (Status: $create_http_status).\n"
                    overall_status="Erro"
                    instance_has_errors=1
                fi
                if [ "$instance_has_errors" -eq 0 ]; then
                     vps_details_summary+="  - Status da VPS: Sucesso\n"
                else
                     vps_details_summary+="  - Status da VPS: Erros encontrados\n"
                fi
                sleep 5
            done
        fi
    fi

    log_message "Processo de gerenciamento de snapshots concluído."

    # Montar a mensagem final do WhatsApp
    local final_report="Detalhe dos seus Backups na Contabo (${TIMESTAMP_EXEC}):\n"
    final_report+="$vps_details_summary" # Detalhes por VPS já formatados

    # Adicionar seções de deletados e criados apenas se houver itens
    if ! grep -q "VPS:" <<< "$deleted_snapshots_summary"; then # Verifica se algo além do cabeçalho foi adicionado
        deleted_snapshots_summary+="  - Nenhum backup deletado nesta execução.\n"
    fi
    final_report+="\n${deleted_snapshots_summary}"

    if ! grep -q "VPS:" <<< "$created_snapshots_summary"; then
        created_snapshots_summary+="  - Nenhum backup criado nesta execução.\n"
    fi
    final_report+="\n${created_snapshots_summary}"


    final_report+="\nStatus da operação: $overall_status\n"
    if [ "$overall_status" == "Erro" ]; then
        if ! grep -q "VPS:" <<< "$error_messages_summary" && ! grep -q "Falha ao obter" <<< "$error_messages_summary"; then # Verifica se algo além do cabeçalho foi adicionado
             error_messages_summary+="  - Nenhuma mensagem de erro específica registrada (verifique os logs).\n"
        fi
        final_report+="\n${error_messages_summary}"
    fi

    send_whatsapp_notification "$final_report"

    exit 0
}

# --- Execução ---
main