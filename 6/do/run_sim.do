# ==============================================================================
# UTFPR - DAELN - ELEW33 (Logica Reconfiguravel)
# Script ModelSim para Simulacao do User HW + BRAM 1024x8
# Alunos: Roberto Luiz Vieira Filho & Omar Zagonel El Laden
# ==============================================================================

# Cria biblioteca work se nao existir
vlib work
vmap work work

# Compila arquivos fonte VHDL
vcom -reportprogress 300 -work work ../src/hw/BRAM.vhd
vcom -reportprogress 300 -work work ../src/hw/reg32_avalon_interface.vhd
vcom -reportprogress 300 -work work ../tb/user_hw_tb.vhd

# Inicia simulacao com biblioteca altera_mf
vsim -t 1ps -L altera_mf work.user_hw_tb

# Desativa warnings numericos desnecessarios
set NumericStdNoWarnings 1
set StdArithNoWarnings   1

# Configuracao das formas de onda (Waves)
add wave -divider "CLOCK E RESET"
add wave -noupdate /user_hw_tb/clock
add wave -noupdate /user_hw_tb/resetn

add wave -divider "BARRAMENTO AVALON-MM"
add wave -noupdate /user_hw_tb/chipselect
add wave -noupdate /user_hw_tb/write_en
add wave -noupdate /user_hw_tb/read_en
add wave -noupdate -radix binary /user_hw_tb/add
add wave -noupdate -radix hexadecimal /user_hw_tb/writedata
add wave -noupdate -radix hexadecimal /user_hw_tb/readdata

add wave -divider "USER HW - REGISTRADORES & STATUS"
add wave -noupdate -radix unsigned /user_hw_tb/dut/reg_add
add wave -noupdate -radix ascii    /user_hw_tb/dut/reg_data_wr
add wave -noupdate -radix ascii    /user_hw_tb/dut/reg_data_rd
add wave -noupdate -radix hexadecimal /user_hw_tb/dut/hw_checksum
add wave -noupdate -radix unsigned /user_hw_tb/dut/hw_seq_reg
add wave -noupdate /user_hw_tb/dut/match_reg
add wave -noupdate -radix unsigned /user_hw_tb/dut/hw_byte_count

add wave -divider "BRAM 1024x8 (INTERFACE & TRI-STATE)"
add wave -noupdate /user_hw_tb/dut/bram_inst/CS
add wave -noupdate /user_hw_tb/dut/bram_inst/WR_EN
add wave -noupdate /user_hw_tb/dut/bram_inst/RD_EN
add wave -noupdate -radix unsigned /user_hw_tb/dut/bram_inst/ADD
add wave -noupdate -radix ascii    /user_hw_tb/dut/bram_inst/WRITEDATA
add wave -noupdate -radix ascii    /user_hw_tb/dut/bram_inst/READDATA

# Executa a simulacao
run -all
wave zoom full
