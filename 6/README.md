# Projeto 6: Integração NIOS II + User HW (BRAM 1024x8 com Checksum)

**Disciplina:** Lógica Reconfigurável (ELEW33) - UTFPR  
**Alunos:** Roberto Luiz Vieira Filho & Omar Zagonel El Laden  

---

## 1. Visão Geral da Arquitetura

O projeto integra um microprocessador softcore **NIOS II** gerado via **Qsys** com um componente de hardware desenvolvido pelo usuário (**User HW** - `reg32_avalon_interface`), que por sua vez encapsula uma memória **Block RAM de 1024 x 8 bits** (`BRAM`) e um módulo de verificação de integridade (**Checksum** e **Número de Sequência**).

### Especificações Técnicas Atendidas

1. **Instanciação da BRAM 1024x8**:
   - Memória Single-Port gerada através da megafunção `altsyncram` (compatível com a família Cyclone II).
   - Largura de palavra: 8 bits (`width_a = 8`).
   - Profundidade: 1024 palavras (`numwords_a = 1024`, barramento de endereços de 10 bits `ADD(9 downto 0)`).
   - Saída não registrada (`UNREGISTERED`) para leitura imediata no ciclo de ativação.

2. **Controle de Escrita e Leitura (Regras 4 e 5)**:
   - **Escrita**: A memória só é gravada quando `CS = '1'` e `WR_EN = '1'`. Se `CS = '0'`, o conteúdo permanece inalterado.
   - **Leitura**: Se `CS = '0'` ou leitura desabilitada, o barramento de saída `READDATA` permanece em alta impedância (`'Z'` / Tri-State). Quando `CS = '1'` e `RD_EN = '1'`, `READDATA` recebe o valor da posição de memória endereçada.

3. **Mapa de Registradores Avalon-MM (Regra 6)**:
   O barramento do escravo Avalon utiliza 32 bits de dados e 2 bits de endereço (`add(1 downto 0)`), mapeados em palavras de 4 bytes:
   
   | `add` | Offset Bytes | Registrador | Descrição |
   |:---:|:---:|:---|:---|
   | `"00"` | `0x00` (`ADDR_OFFSET`) | **Endereços (AA 9..0)** | Posição de memória a ser acessada (0 a 1023). |
   | `"01"` | `0x04` (`DATA_OFFSET`) | **Dados (DD 7..0)** | Dado a ser gravado (na escrita) ou dado lido da BRAM (na leitura). |
   | `"10"` | `0x08` (`CTRL_OFFSET`) | **Controle e Status** | Comandos de operação e handshake de integridade. |

4. **Operações e Registrador de Controle (Regras 7 e 8)**:
   - **Escrita de Dado na BRAM**:
     1. Escrever o endereço no registro `"00"`.
     2. Escrever o dado no registro `"01"`.
     3. Escrever `MEM_WR_BIT` (`(1 << 1)`) no registro de controle `"10"`. O hardware gera um pulso auto-limpante (*Self-Clear*) de 1 ciclo em `CS` e `WR_EN` da BRAM, e acumula o byte no checksum do HW.
   - **Leitura de Dado da BRAM**:
     1. Escrever o endereço no registro `"00"`.
     2. Escrever `MEM_RD_BIT` (`(1 << 0)`) no registro de controle `"10"`. O hardware gera um pulso auto-limpante (*Self-Clear*) em `CS` e `RD_EN`, capturando o byte da BRAM.
     3. Ler o dado no registro `"01"` (`DATA_OFFSET`).

5. **Mecanismo de Checksum e Handshake de Sequência**:
   - O software escreve 1024 bytes contendo a repetição do nome completo dos alunos em ASCII sem acentos, intercalados pela sequência `" +++--+++ "` (10 caracteres).
   - O software calcula o checksum dos 1024 bytes (soma sem sinal de 8 bits).
   - O software envia o pacote de handshake para `CTRL_OFFSET`:
     - Bits 31..24: Número de Sequência (`sequence`).
     - Bits 23..16: Checksum calculado pelo SW (`checksum_sw`).
   - O User HW compara o seu checksum acumulado com o checksum enviado pelo SW e aciona a flag `match_reg = '1'`.
   - O software lê `CTRL_OFFSET`, recebendo o número de sequência confirmado, o checksum do HW e a flag de validação.
   - O software só envia um novo bloco de 1024 bytes após validar que o número de sequência e o checksum conferem.
   - O software lê de volta os 1024 bytes da BRAM e os imprime na UART / JTAG UART.

---

## 2. Estrutura de Arquivos

```
6/
├── do/
│   └── run_sim.do                  # Script TCL/DO para automatizacao da simulacao ModelSim
├── src/
│   ├── hw/
│   │   ├── BRAM.vhd                # Componente BRAM 1024x8 com interface Tri-State (altsyncram)
│   │   ├── reg32_avalon_interface.vhd # Top-level do User HW com interface escrava Avalon-MM
│   │   └── user_hw.tcl             # Descritor do componente para integracao no Qsys
│   └── sw/
│       └── hello_world.c           # Software C99 para NIOS II (escrita, leitura, checksum e UART)
├── tb/
│   └── user_hw_tb.vhd              # Testbench completo e auto-verificavel para ModelSim
└── README.md                       # Documentacao e guia de reproducao
```

---

## 3. Instruções de Reprodução e Simulação

### A. Simulação Funcional no ModelSim (User HW Standalone)

Para verificar o funcionamento completo do User HW e BRAM diretamente no ModelSim:

1. Abra o **ModelSim**.
2. Altere o diretório corrente para a pasta `6/do/` (ou execute pelo terminal):
   ```tcl
   cd C:/Users/rober/utfpr/2026-2/logica-reconfiguravel/ELEW33/6/do
   do run_sim.do
   ```
3. O script irá:
   - Compilar `BRAM.vhd`, `reg32_avalon_interface.vhd` e `user_hw_tb.vhd`.
   - Iniciar a simulação carregando a biblioteca `altera_mf`.
   - Adicionar as ondas organizadas por categorias, formatando `READDATA` e `WRITEDATA` como **ASCII**.
   - Gravar 1024 bytes, enviar o handshake, verificar o checksum e ler de volta todos os 1024 bytes.
   - Imprimir a mensagem de sucesso no Transcript:
     `# ** Note: === TESTE FINALIZADO COM SUCESSO ===`

### B. Integração no Qsys e Quartus II

1. No diretório do projeto Quartus (`qsys_2026_2` ou `lab6`), abra o **Qsys**.
2. No menu **Component Library -> Project**, abra ou recarregue o componente `user`:
   - Verifique que os arquivos associados apontam para `hw/reg32_avalon_interface.vhd` (Top-level) e `hw/BRAM.vhd`.
   - Na aba **Signals**, certifique-se de que o sinal `add` possui largura de **2 bits** (`address`).
3. Conecte o componente `user_0`:
   - `clock_sink` -> `clk_0.clk`
   - `reset_sink` -> `clk_0.clk_reset`
   - `avalon_slave_0` -> `cpu.data_master`
   - Atribua o endereço base (ex.: `0x2020` ou via *Assign Base Addresses*).
4. Clique em **Generate HDL** para gerar a descrição do sistema para síntese e simulação.
5. No Quartus II, realize a compilação completa (**Processing -> Start Compilation**).

### C. Execução do Software no Eclipse (Nios II SBT)

1. No Nios II Software Build Tools for Eclipse, abra o projeto de software (`hello_world.c`).
2. Garanta que a flag `-std=c99` esteja habilitada no `Makefile` (`APP_CFLAGS_USER_FLAGS := -std=c99`).
3. Clique com o botão direito no projeto BSP -> **Nios II -> Generate BSP**.
4. Compile o projeto (**Build Project**).
5. Gere os arquivos de inicialização de memória (**Make Targets -> Build -> mem_init_generate**).
6. Para simular integradamente:
   - Clique com o botão direito no projeto -> **Run As -> Nios II ModelSim**.
   - No ModelSim, observe o sinal `bram_inst/READDATA` exibindo continuamente o nome dos alunos em ASCII.
   - O console UART/Transcript exibirá o número de sequência, os checksums calculados e o status `Match = TRUE`.
