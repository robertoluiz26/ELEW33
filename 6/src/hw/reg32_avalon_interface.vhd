-- ==============================================================================
-- UTFPR - DAELN - ELEW33 (Logica Reconfiguravel)
-- Projeto: Componente User HW / Interface Avalon-MM para BRAM e Checksum
-- Alunos: Roberto Luiz Vieira Filho & Omar Zagonel El Laden
-- ==============================================================================
-- Mapa de Registradores (Barramento de 32 bits, add de 2 bits):
-- ADD = "00" (Offset 0x00): Registro de Enderecos (AA 9..0)
-- ADD = "01" (Offset 0x04): Registro de Dados (DD 7..0)
-- ADD = "10" (Offset 0x08): Registro de Controle e Status:
--   Escrita:
--     Bit 0: RD_MEM  - Habilita leitura na BRAM (Self-Clear)
--     Bit 1: WE_MEM  - Habilita escrita na BRAM (Self-Clear)
--     Bit 2: CHK_RST - Zera o acumulador de checksum e contador do HW
--     Bits 23..16: Checksum calculado pelo software (NIOS)
--     Bits 31..24: Numero de sequencia enviado pelo software (NIOS)
--   Leitura:
--     Bit 0: RD_MEM status ('0' apos self-clear)
--     Bit 1: WE_MEM status ('0' apos self-clear)
--     Bit 7: Flag de Match (1 se checksum HW == SW, 0 se mismatch)
--     Bits 15..8:  Checksum calculado pelo HW (compatibilidade >> 8)
--     Bits 23..16: Checksum calculado pelo HW (compatibilidade >> 16)
--     Bits 31..24: Numero de sequencia confirmado pelo HW
-- ==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg32_avalon_interface is
port(
    clock      : in  std_logic;
    resetn     : in  std_logic;
    chipselect : in  std_logic;
    write_en   : in  std_logic;
    read_en    : in  std_logic;
    add        : in  std_logic_vector(1 downto 0);
    writedata  : in  std_logic_vector(31 downto 0);
    readdata   : out std_logic_vector(31 downto 0)
);
end entity reg32_avalon_interface;

architecture rtl of reg32_avalon_interface is

    -- Componente BRAM 1024x8 com interface Tri-State
    component BRAM is
    port(
        CLK       : in  std_logic;
        RST       : in  std_logic;
        CS        : in  std_logic;
        WR_EN     : in  std_logic;
        RD_EN     : in  std_logic;
        ADD       : in  std_logic_vector(9 downto 0);
        WRITEDATA : in  std_logic_vector(7 downto 0);
        READDATA  : out std_logic_vector(7 downto 0)
    );
    end component;

    -- Sinais internos para BRAM
    signal s_rst            : std_logic;
    signal s_bram_cs        : std_logic := '0';
    signal s_bram_wren      : std_logic := '0';
    signal s_bram_rden      : std_logic := '0';
    signal s_bram_add       : std_logic_vector(9 downto 0) := (others => '0');
    signal s_bram_writedata : std_logic_vector(7 downto 0) := (others => '0');
    signal s_bram_readdata  : std_logic_vector(7 downto 0);

    -- Registradores de interface
    signal reg_add          : std_logic_vector(9 downto 0) := (others => '0');
    signal reg_data_wr      : std_logic_vector(7 downto 0) := (others => '0');
    signal reg_data_rd      : std_logic_vector(7 downto 0) := (others => '0');

    -- Registradores para calculo e verificacao de checksum e sequencia
    signal hw_checksum      : unsigned(7 downto 0) := (others => '0');
    signal hw_seq_reg       : std_logic_vector(7 downto 0) := (others => '0');
    signal sw_checksum_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal match_reg        : std_logic := '0';
    signal hw_byte_count    : unsigned(10 downto 0) := (others => '0');

    -- Controle de pulsos auto-limpantes (Self-Clear)
    signal s_we_pulse       : std_logic := '0';
    signal s_rd_pulse       : std_logic := '0';

begin

    s_rst <= not resetn;

    -- Instanciacao do componente BRAM
    bram_inst: BRAM
    port map(
        CLK       => clock,
        RST       => s_rst,
        CS        => s_bram_cs,
        WR_EN     => s_bram_wren,
        RD_EN     => s_bram_rden,
        ADD       => s_bram_add,
        WRITEDATA => s_bram_writedata,
        READDATA  => s_bram_readdata
    );

    s_bram_add       <= reg_add;
    s_bram_writedata <= reg_data_wr;

    -- Processo sincrono para gravacao dos registradores e logica de controle
    process(clock, resetn)
    begin
        if resetn = '0' then
            reg_add         <= (others => '0');
            reg_data_wr     <= (others => '0');
            reg_data_rd     <= (others => '0');
            hw_checksum     <= (others => '0');
            hw_seq_reg      <= (others => '0');
            sw_checksum_reg <= (others => '0');
            match_reg       <= '0';
            hw_byte_count   <= (others => '0');
            s_bram_cs       <= '0';
            s_bram_wren     <= '0';
            s_bram_rden     <= '0';
            s_we_pulse      <= '0';
            s_rd_pulse      <= '0';

        elsif rising_edge(clock) then
            -- Padrao de auto-limpeza (Self-Clear): sinais de controle da BRAM
            -- voltam a '0' apos o ciclo ativo
            if s_bram_cs = '1' then
                if s_bram_rden = '1' then
                    -- Captura a saida da BRAM antes de desabilitar o CS
                    reg_data_rd <= s_bram_readdata;
                end if;
                s_bram_cs   <= '0';
                s_bram_wren <= '0';
                s_bram_rden <= '0';
                s_we_pulse  <= '0';
                s_rd_pulse  <= '0';
            end if;

            -- Escrita via barramento Avalon
            if chipselect = '1' and write_en = '1' then
                case add is
                    -- ADD = "00": Registro de Enderecos (9..0)
                    when "00" =>
                        reg_add <= writedata(9 downto 0);

                    -- ADD = "01": Registro de Dados (7..0)
                    when "01" =>
                        reg_data_wr <= writedata(7 downto 0);

                    -- ADD = "10": Registro de Controle
                    when "10" =>
                        -- Bit 2: Reset do checksum e contador do HW
                        if writedata(2) = '1' then
                            hw_checksum   <= (others => '0');
                            hw_byte_count <= (others => '0');
                            match_reg     <= '0';
                        end if;

                        -- Bit 1: WE_MEM (Self-Clear) - Grava dado na BRAM e acumula Checksum
                        if writedata(1) = '1' then
                            s_bram_cs     <= '1';
                            s_bram_wren   <= '1';
                            s_bram_rden   <= '0';
                            s_we_pulse    <= '1';
                            -- Acumula Checksum e incrementa contagem
                            hw_checksum   <= hw_checksum + unsigned(reg_data_wr);
                            hw_byte_count <= hw_byte_count + 1;

                        -- Bit 0: RD_MEM (Self-Clear) - Inicia ciclo de leitura na BRAM
                        elsif writedata(0) = '1' then
                            s_bram_cs   <= '1';
                            s_bram_rden <= '1';
                            s_bram_wren <= '0';
                            s_rd_pulse  <= '1';
                        end if;

                        -- Handshake de Sequencia e Checksum (bits 31..16)
                        -- Quando NIOS envia o pacote de controle com seq e chk:
                        if writedata(31 downto 16) /= x"0000" then
                            hw_seq_reg      <= writedata(31 downto 24);
                            sw_checksum_reg <= writedata(23 downto 16);

                            -- Compara o Checksum calculado pelo HW com o enviado pelo SW
                            if hw_checksum = unsigned(writedata(23 downto 16)) then
                                match_reg <= '1';
                            else
                                match_reg <= '0';
                            end if;
                        end if;

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- Processo combinacional para leitura no barramento Avalon
    process(add, reg_add, reg_data_rd, hw_seq_reg, hw_checksum, match_reg, s_we_pulse, s_rd_pulse)
    begin
        case add is
            -- ADD = "00": Leitura do endereco atual
            when "00" =>
                readdata <= std_logic_vector(resize(unsigned(reg_add), 32));

            -- ADD = "01": Leitura do ultimo dado lido da memoria
            when "01" =>
                readdata <= x"000000" & reg_data_rd;

            -- ADD = "10": Leitura do registrador de status / handshake
            -- Bits 31..24: Numero de sequencia confirmado pelo HW
            -- Bits 23..16: Checksum calculado pelo HW
            -- Bits 15..8:  Checksum calculado pelo HW (compatibilidade >> 8)
            -- Bit  7:      Flag Match (1 = OK, 0 = divergencia)
            -- Bit  1:      WE_MEM status (0 quando liberado)
            -- Bit  0:      RD_MEM status (0 quando liberado)
            when "10" =>
                readdata <= hw_seq_reg & 
                            std_logic_vector(hw_checksum) & 
                            std_logic_vector(hw_checksum) & 
                            match_reg & "00000" & s_we_pulse & s_rd_pulse;

            when others =>
                readdata <= (others => '0');
        end case;
    end process;

end architecture rtl;
