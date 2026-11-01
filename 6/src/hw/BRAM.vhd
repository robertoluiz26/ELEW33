-- ==============================================================================
-- UTFPR - DAELN - ELEW33 (Logica Reconfiguravel)
-- Projeto: BRAM 1024 x 8 com Interface Tri-State
-- Alunos: Roberto Luiz Vieira Filho & Omar Zagonel El Laden
-- ==============================================================================
-- Especificacoes atendidas:
-- 1) Instanciacao de Block RAM (1024 x 8) com altsyncram (Quartus)
-- 4) Escrita: a memoria so eh gravada se CS = '1' e WR_EN = '1'. Se CS = '0',
--    o conteudo original eh preservado.
-- 5) Leitura: se CS = '0', o barramento de saida READDATA permanece em 'Z' (tri-state).
--    Se CS = '1' e RD_EN = '1', READDATA recebe o valor da posicao enderecada.
-- ==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity BRAM is
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
end entity BRAM;

architecture syn of BRAM is

    signal ram_q    : std_logic_vector(7 downto 0);
    signal ram_wren : std_logic;

    component altsyncram
    generic (
        clock_enable_input_a   : string;
        clock_enable_output_a  : string;
        intended_device_family : string;
        lpm_hint               : string;
        lpm_type               : string;
        numwords_a             : natural;
        operation_mode         : string;
        outdata_aclr_a         : string;
        outdata_reg_a          : string;
        power_up_uninitialized : string;
        widthad_a              : natural;
        width_a                : natural;
        width_byteena_a        : natural
    );
    port (
        address_a : in  std_logic_vector(9 downto 0);
        clock0    : in  std_logic;
        data_a    : in  std_logic_vector(7 downto 0);
        wren_a    : in  std_logic;
        q_a       : out std_logic_vector(7 downto 0)
    );
    end component;

begin

    -- Regra 4: Escrita somente quando CS = '1' e WR_EN = '1'
    ram_wren <= CS and WR_EN;

    -- Regra 5: Tri-state quando CS = '0' ou leitura desabilitada.
    -- Quando CS = '1' e RD_EN = '1', sai o dado lido da memoria.
    READDATA <= ram_q when (CS = '1' and RD_EN = '1') else (others => 'Z');

    altsyncram_component : altsyncram
    generic map (
        clock_enable_input_a   => "BYPASS",
        clock_enable_output_a  => "BYPASS",
        intended_device_family => "Cyclone II",
        lpm_hint               => "ENABLE_RUNTIME_MOD=NO",
        lpm_type               => "altsyncram",
        numwords_a             => 1024,
        operation_mode         => "SINGLE_PORT",
        outdata_aclr_a         => "NONE",
        outdata_reg_a          => "UNREGISTERED",
        power_up_uninitialized => "FALSE",
        widthad_a              => 10,
        width_a                => 8,
        width_byteena_a        => 1
    )
    port map (
        address_a => ADD,
        clock0    => CLK,
        data_a    => WRITEDATA,
        wren_a    => ram_wren,
        q_a       => ram_q
    );

end architecture syn;
