# Define diretórios de origem dos logs e de saída dos arquivos processados
LOG_DIR="../myapp/logs"
ARQUIVO_DIR="../myapp/logs-processados"                                                                 
TEMP_DIR="../myapp/logs-temp"  

# Cria diretórios de saída caso ainda não existam
mkdir -p $ARQUIVO_DIR                
mkdir -p $TEMP_DIR 

# Busca todos os arquivos .log no diretório especificado
find $LOG_DIR -name "*.log" -print0 | while IFS= read -r -d '' arquivo; do         
        # Filtra linhas que contenham "ERROR" e adiciona ao arquivo .filtrado
        grep "ERROR" $arquivo > "${arquivo}.filtrado"                                     
        # Filtra linhas com "SENSITIVE_DATA" e adiciona ao mesmo arquivo .filtrado
        grep "SENSITIVE_DATA" $arquivo >> "${arquivo}.filtrado"                      
        
        # Redação de dados sensíveis utilizando sed
        sed -i 's/User password is .*/User password is REDACTED/g' "${arquivo}.filtrado"      
        sed -i 's/User password reset request with token .*/User password reset request with token REDACTED/g' "${arquivo}.filtrado" 
        sed -i 's/API key leaked: .*/API key leaked: REDACTED/g' "${arquivo}.filtrado"  
        sed -i 's/User credit card last four digits: .*/User credit card last four digits: REDACTED/g' "${arquivo}.filtrado"
        sed -i 's/User session initiated with token: .*/User session initiated with token: REDACTED/g' "${arquivo}.filtrado"

        # Ordena o conteúdo filtrado
        sort "${arquivo}.filtrado" -o "${arquivo}.filtrado"

        # Remove linhas duplicadas
        uniq "${arquivo}.filtrado" > "${arquivo}.unico"

        # Conta o número de palavras e linhas do arquivo .unico
        num_palavras=$(wc -w < "${arquivo}.unico")
        num_linhas=$(wc -l < "${arquivo}.unico")

        # Extrai o nome do arquivo para fins de exibição no relatório
        nome_arquivo=$(basename "${arquivo}.unico")

        # Registra as estatísticas de cada arquivo processado em log_stats
        echo "Arquivo $nome_arquivo" >> "${ARQUIVO_DIR}/log_stats_$(date +%F).txt"
        echo "Número de linhas: $num_linhas" >> "${ARQUIVO_DIR}/log_stats_$(date +%F).txt"
        echo "Número de palavras: $num_palavras" >> "${ARQUIVO_DIR}/log_stats_$(date +%F).txt"
        echo "-----------------------------------" >> "${ARQUIVO_DIR}/log_stats_$(date +%F).txt"

        # Identifica o tipo de log (frontend/backend/outro) e adiciona um prefixo correspondente
        if [[ "$nome_arquivo" == *frontend* ]]; then
                sed 's/^/[FRONTEND] /' "${arquivo}.unico" >> "${ARQUIVO_DIR}/logs_combinados_$(date +%F).log"
        elif [[ "$nome_arquivo" == *backend* ]]; then
                sed 's/^/[BACKEND] /' "${arquivo}.unico" >> "${ARQUIVO_DIR}/logs_combinados_$(date +%F).log"
        else
                cat "${arquivo}.unico" >> "${ARQUIVO_DIR}/logs_combinados_$(date +%F).log"
        fi

        # Remove arquivos temporários individuais após processamento
        rm -r "${arquivo}.unico"
        rm -r "${arquivo}.filtrado"
done

# Ordena os logs combinados por base na segunda coluna (ex: data/hora)
sort -k2 "${ARQUIVO_DIR}/logs_combinados_$(date +%F).log" -o "${ARQUIVO_DIR}/logs_combinados_$(date +%F).log"

# Move os arquivos combinados e estatísticos para diretório temporário
mv "${ARQUIVO_DIR}/logs_combinados_$(date +%F).log" "$TEMP_DIR/"
mv "${ARQUIVO_DIR}/log_stats_$(date +%F).txt" "$TEMP_DIR/"

# Compacta os arquivos temporários em um único arquivo .tar.gz
# A opção -C muda para o diretório antes da compactação, mantendo a estrutura relativa
tar -czf "${ARQUIVO_DIR}/logs_$(date +%F).tar.gz" -C "$TEMP_DIR" .

# Remove o diretório temporário após a compactação
rm -r "$TEMP_DIR"

