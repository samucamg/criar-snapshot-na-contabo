# Script de Automação com Contabo API e Evolution API

Este script foi desenvolvido para interagir com a API da Contabo e a Evolution API, permitindo automatizar diversas tarefas. Ele é configurável através de um arquivo `config.conf` onde você insere suas credenciais e informações das APIs.

**Atenção:** Este script requer que você insira suas credenciais da Contabo e chaves da Evolution API em um arquivo de configuração. Certifique-se de proteger este arquivo e considere as implicações de segurança. **É altamente recomendável adicionar `config.conf` ao seu arquivo `.gitignore` para evitar o envio acidental de suas credenciais para o GitHub.**

---

✨ **Confira meu canal no YouTube para tutoriais em vídeo deste e de outros sistemas!** ✨
[Canal Samuca Tutoriais no YouTube](https://www.youtube.com/@samucamg)

Me siga no GitHub: [samucamg](https://github.com/samucamg/)

---

<details>
<summary><strong>📜 Funcionalidades</strong></summary>

* Listar servidores da Contabo.
* Excluir o último snaphot de todos os servidores.
* Criar um novo snapshot de todos os servidores.
*(Adicione aqui as funcionalidades específicas do SEU script)*

</details>

<details>
<summary><strong>🛠️ Pré-requisitos</strong></summary>

* Python 3.x instalado.
* Conta na [Contabo](https://contabo.com/).
* Acesso à [Evolution API](https://evolution-api.com/) (ou a documentação da sua instância).
* Bibliotecas Python:
    * `requests` (para chamadas HTTP)
    * `configparser` (para ler o arquivo de configuração)
    * (Liste outras bibliotecas que seu script possa necessitar)

    Você pode instalar as bibliotecas necessárias usando o pip:
    ```bash
    pip install requests configparser
    ```
    *(Adapte o comando acima com todas as bibliotecas que seu script realmente usa)*
</details>

<details>
<summary><strong>⚙️ Configuração</strong></summary>

Antes de executar o script, você precisa configurar suas credenciais e informações das APIs no arquivo `config.conf`.

1.  **Crie o arquivo `config.conf`** na mesma pasta do script com o seguinte conteúdo:

    ```ini
    [CONTABO]
    ClientId = SEU_CLIENT_ID_CONTABO
    ClientSecret = SEU_CLIENT_SECRET_CONTABO
    ApiUser = seuemaildelogin@gmail.com
    ApiPassword = SUASENHADECONTABO

    [EVOLUTION]
    ApiUrl = [https://api.seudominio.com](https://api.seudominio.com)
    Instance = NOME_DA_SUA_INSTANCIA
    ApiKey = SEU_API_KEY_DA_INSTANCIA
    ```

2.  **Obtendo as credenciais da Contabo API:**
    * Acesse o site da Contabo: [https://my.contabo.com/](https://my.contabo.com/)
    * Faça login com seu usuário e senha.
    * No menu do lado esquerdo, navegue até a aba "API".
    * **ClientID:** Este valor geralmente é exibido diretamente na página da API.
    * **Client Secret:**
        * Se já existir uma chave, pode haver um botão como "Reveal Client Secret" ou "Mostrar Segredo do Cliente".
        * Caso contrário, ou se desejar uma nova, clique em "Regenerate Client Secret" ou "Gerar Novo Segredo do Cliente". **Atenção:** Ao regenerar o Client Secret, o anterior deixará de funcionar. Guarde o novo Client Secret em local seguro, pois ele só será exibido uma vez.
    * **ApiUser:** É o seu e-mail de login na Contabo.
    * **ApiPassword:** É a sua senha de acesso à Contabo.

3.  **Obtendo as credenciais da Evolution API:**
    * **ApiUrl:** É o endereço da sua instância da Evolution API. **Importante:** Não inclua a barra `/` no final (ex: `https://api.seudominio.com`, e não `https://api.seudominio.com/`).
    * **Instance:** O nome ou identificador da sua instância na Evolution API.
    * **ApiKey:** O token de API fornecido pela sua instância da Evolution API para autenticação.

**Importante sobre Segurança:**
O arquivo `config.conf` conterá informações sensíveis. Certifique-se de que este arquivo não seja enviado para repositórios públicos. Adicione `config.conf` ao seu arquivo `.gitignore` para evitar que ele seja rastreado pelo Git.

Crie um arquivo chamado `.gitignore` na raiz do seu projeto (se ainda não existir) e adicione a seguinte linha:

config.conf

</details>

<details>
<summary><strong>🚀 Como Executar o Script</strong></summary>

1.  Certifique-se de que o Python e as bibliotecas necessárias estão instalados.
2.  Configure o arquivo `config.conf` conforme as instruções acima.
3.  Abra um terminal ou prompt de comando.
4.  Navegue até a pasta onde o script e o `config.conf` estão localizados.
5.  Execute o script usando o Python:

    ```bash
    python nome_do_seu_script.py
    ```
    (Substitua `nome_do_seu_script.py` pelo nome real do seu arquivo Python)

</details>

<details>
<summary><strong>⏰ Agendando a Execução do Script</strong></summary>

Você pode agendar a execução automática do script em horários definidos.

<details>
<summary>🐧 No Linux (usando Cron)</summary>

O Cron é um utilitário de agendamento de tarefas baseado em tempo em sistemas operacionais do tipo Unix.

1.  **Abra o editor do crontab:**
    No terminal, digite:
    ```bash
    crontab -e
    ```
    Se for a primeira vez, pode ser solicitado que você escolha um editor (como nano, vim, etc.). Para iniciantes, `nano` é uma boa opção.

2.  **Adicione uma nova linha de agendamento:**
    A sintaxe básica do cron é:
    ```
    MINUTO HORA DIA_DO_MÊS MÊS DIA_DA_SEMANA /caminho/completo/para/python /caminho/completo/para/seu_script.py
    ```
    * `MINUTO`: 0-59
    * `HORA`: 0-23
    * `DIA_DO_MÊS`: 1-31
    * `MÊS`: 1-12
    * `DIA_DA_SEMANA`: 0-7 (0 e 7 são Domingo)
    * Use `*` para "qualquer valor".

    **Exemplos:**

    * **Executar o script todos os dias às 02:30 da manhã:**
        ```cron
        30 2 * * * /usr/bin/python3 /home/seu_usuario/caminho/para/seu_script.py
        ```
        *(Certifique-se de usar o caminho correto para o interpretador Python (`which python3` para descobrir) e para o seu script)*

    * **Executar a cada hora:**
        ```cron
        0 * * * * /usr/bin/python3 /home/seu_usuario/caminho/para/seu_script.py
        ```

    * **Executar a cada 15 minutos:**
        ```cron
        */15 * * * * /usr/bin/python3 /home/seu_usuario/caminho/para/seu_script.py
        ```

3.  **Salve e saia do editor.**
    * Se estiver usando `nano`, pressione `Ctrl+X`, depois `Y` e `Enter`.

4.  **Verificar os agendamentos ativos (opcional):**
    ```bash
    crontab -l
    ```

**Dica para Logs no Cron:**
É uma boa prática redirecionar a saída do seu script para um arquivo de log para depuração:
```cron
30 2 * * * /usr/bin/python3 /home/seu_usuario/caminho/para/seu_script.py >> /home/seu_usuario/caminho/para/script.log 2>&1
