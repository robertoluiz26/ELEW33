-- ==============================================================================
-- UTFPR - DAELN - ELEW33 (Logica Reconfiguravel)
-- Testbench: user_hw_tb (Simulacao ModelSim do User HW + BRAM)
-- Alunos: Roberto Luiz Vieira Filho & Omar Zagonel El Laden
-- ==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity user_hw_tb is
end entity user_hw_tb;

architecture tb of user_hw_tb is

    component reg32_avalon_interface is
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
    end component;

    signal clock      : std_logic := '0';
    signal resetn     : std_logic := '0';
    signal chipselect : std_logic := '0';
    signal write_en   : std_logic := '0';
    signal read_en    : std_logic := '0';
    signal add        : std_logic_vector(1 downto 0) := (others => '0');
    signal writedata  : std_logic_vector(31 downto 0) := (others => '0');
    signal readdata   : std_logic_vector(31 downto 0);

    signal sim_finished : boolean := false;

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz

    -- Procedimento para escrita no barramento Avalon
    procedure avalon_write(
        constant p_add  : in std_logic_vector(1 downto 0);
        constant p_data : in std_logic_vector(31 downto 0);
        signal clk      : in std_logic;
        signal cs       : out std_logic;
        signal we       : out std_logic;
        signal addr_sig : out std_logic_vector(1 downto 0);
        signal data_sig : out std_logic_vector(31 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        cs       <= '1';
        we       <= '1';
        addr_sig <= p_add;
        data_sig <= p_data;
        wait until rising_edge(clk);
        cs       <= '0';
        we       <= '0';
        data_sig <= (others => '0');
    end procedure;

    -- Procedimento para leitura no barramento Avalon
    procedure avalon_read(
        constant p_add  : in std_logic_vector(1 downto 0);
        signal clk      : in std_logic;
        signal cs       : out std_logic;
        signal re       : out std_logic;
        signal addr_sig : out std_logic_vector(1 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        cs       <= '1';
        re       <= '1';
        addr_sig <= p_add;
        wait until rising_edge(clk);
        cs       <= '0';
        re       <= '0';
    end procedure;

begin

    -- Instancia a Device Under Test (DUT)
    dut: reg32_avalon_interface
    port map(
        clock      => clock,
        resetn     => resetn,
        chipselect => chipselect,
        write_en   => write_en,
        read_en    => read_en,
        add        => add,
        writedata  => writedata,
        readdata   => readdata
    );

    -- Geracao de Clock (50 MHz)
    clk_gen: process
    begin
        while not sim_finished loop
            clock <= '0';
            wait for CLK_PERIOD / 2;
            clock <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Processo de estimulos
    stim_proc: process
        constant TEST_NAME : string := "ROBERTO LUIZ VIEIRA FILHO +++--+++ OMAR ZAGONEL EL LADEN +++--+++ ";
        variable v_char    : character;
        variable v_val     : integer;
        variable v_chk_sw  : unsigned(7 downto 0) := (others => '0');
        variable v_seq_sw  : unsigned(7 downto 0) := x"01";
        variable v_rd_val  : std_logic_vector(7 downto 0);
    begin
        -- 1) Reset do sistema
        resetn <= '0';
        wait for 60 ns;
        resetn <= '1';
        wait for 40 ns;

        report "=== INICIANDO TESTE DO USER HW ===" severity note;

        -- 2) Reset do checksum acumulador no HW (Bit 2 do CTRL)
        avalon_write("10", x"00000004", clock, chipselect, write_en, add, writedata);
        wait for 40 ns;

        -- 3) Escrever 1024 bytes na BRAM
        report "Gravando 1024 bytes na BRAM..." severity note;
        for i in 0 to 1023 loop
            v_char := TEST_NAME((i mod TEST_NAME'length) + 1);
            v_val  := character'pos(v_char);
            v_chk_sw := v_chk_sw + to_unsigned(v_val, 8);

            -- Passo 1: Escreve Endereco (ADD = "00")
            avalon_write("00", std_logic_vector(to_unsigned(i, 32)), clock, chipselect, write_en, add, writedata);

            -- Passo 2: Escreve Dado (ADD = "01")
            avalon_write("01", std_logic_vector(to_unsigned(v_val, 32)), clock, chipselect, write_en, add, writedata);

            -- Passo 3: Pulso de Escrita WE_MEM (ADD = "10", bit 1 = 1)
            avalon_write("10", x"00000002", clock, chipselect, write_en, add, writedata);
        end loop;

        report "Escrita de 1024 bytes concluida! Checksum SW: " & integer'image(to_integer(v_chk_sw)) severity note;

        -- 4) Handshake: Enviar Sequencia (31..24) e Checksum (23..16)
        report "Enviando Handshake de Sequencia e Checksum..." severity note;
        avalon_write("10", 
                     std_logic_vector(v_seq_sw) & std_logic_vector(v_chk_sw) & x"0000", 
                     clock, chipselect, write_en, add, writedata);
        wait for 40 ns;

        -- 5) Leitura do registrador de status (ADD = "10")
        avalon_read("10", clock, chipselect, read_en, add);
        wait for 20 ns;

        -- Verificacao das flags de retorno
        assert readdata(7) = '1'
            report "FALHA: Flag match_reg /= '1' no User HW!" severity error;
        assert readdata(31 downto 24) = std_logic_vector(v_seq_sw)
            report "FALHA: Sequencia HW /= Sequencia SW!" severity error;
        assert readdata(23 downto 16) = std_logic_vector(v_chk_sw)
            report "FALHA: Checksum HW /= Checksum SW!" severity error;

        report "Handshake CONFIRMADO com sucesso pelo User HW!" severity note;

        -- 6) Leitura dos 1024 bytes da BRAM
        report "Lendo e verificando os 1024 bytes da BRAM..." severity note;
        for i in 0 to 1023 loop
            v_char := TEST_NAME((i mod TEST_NAME'length) + 1);
            v_val  := character'pos(v_char);

            -- Passo 1: Configura Endereco (ADD = "00")
            avalon_write("00", std_logic_vector(to_unsigned(i, 32)), clock, chipselect, write_en, add, writedata);

            -- Passo 2: Pulso de Leitura RD_MEM (ADD = "10", bit 0 = 1)
            avalon_write("10", x"00000001", clock, chipselect, write_en, add, writedata);
            wait for 20 ns;

            -- Passo 3: Le Dado (ADD = "01")
            avalon_read("01", clock, chipselect, read_en, add);
            wait for 20 ns;

            v_rd_val := readdata(7 downto 0);

            assert to_integer(unsigned(v_rd_val)) = v_val
                report "ERRO no indice " & integer'image(i) & ": Esperado " & integer'image(v_val) & 
                       " (" & v_char & "), Lido: " & integer'image(to_integer(unsigned(v_rd_val)))
                severity error;
        end loop;

        report "=== TODOS OS 1024 BYTES FORAM LIDOS E CONFERIDOS COM SUCESSO! ===" severity note;
        report "=== TESTE FINALIZADO COM SUCESSO ===" severity note;

        sim_finished <= true;
        wait;
    end process;

end architecture tb;
