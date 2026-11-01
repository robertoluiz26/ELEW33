/*
 * ==============================================================================
 * UTFPR - DAELN - ELEW33 (Logica Reconfiguravel)
 * Software NIOS II - Comunicacao com User HW (BRAM 1024x8 + Checksum)
 * Alunos: Roberto Luiz Vieira Filho & Omar Zagonel El Laden
 * ==============================================================================
 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include "io.h"
#include "system.h"

/* Avalon slave register offsets (byte offsets para enderecamento de palavras) */
#define ADDR_OFFSET  0
#define DATA_OFFSET  4
#define CTRL_OFFSET  8

/* Mascaras de bits do registrador de controle (conforme especificacao) */
/* Bit 0: RD_MEM (Self-Clear)                                          */
/* Bit 1: WE_MEM (Self-Clear)                                          */
/* Bit 2: CHK_RST (Reset checksum e contador de bytes do HW)           */
#define MEM_RD_BIT   (1 << 0)
#define MEM_WR_BIT   (1 << 1)
#define CHK_RST_BIT  (1 << 2)

/* Base address do componente User HW no Qsys */
#ifndef USER_0_BASE
#ifdef USER_BASE
#define USER_0_BASE USER_BASE
#else
#define USER_0_BASE 0x2020
#endif
#endif

#define HW_BASE  USER_0_BASE
#define NUM_WR   1024

void delay(uint32_t iterations)
{
    volatile uint32_t k;
    for (k = 0; k < iterations; k++) {}
}

/* 7) Para fazer qualquer operacao de escrita:                   */
/*    Escrever endereco, dado e comando de controle WE_MEM       */
void write_byte(uint32_t memory_idx, uint8_t byte_val)
{
    IOWR_32DIRECT(HW_BASE, ADDR_OFFSET, memory_idx);
    IOWR_32DIRECT(HW_BASE, DATA_OFFSET, byte_val);
    IOWR_32DIRECT(HW_BASE, CTRL_OFFSET, MEM_WR_BIT);
}

/* 7) Para fazer qualquer operacao de leitura:                   */
/*    Escrever endereco, comando de controle RD_MEM e ler dado   */
uint8_t read_byte(uint32_t memory_idx)
{
    IOWR_32DIRECT(HW_BASE, ADDR_OFFSET, memory_idx);
    IOWR_32DIRECT(HW_BASE, CTRL_OFFSET, MEM_RD_BIT);

    delay(20); /* Aguarda ciclo de leitura na BRAM */

    return (uint8_t)IORD_32DIRECT(HW_BASE, DATA_OFFSET);
}

int main(void)
{
    const char *name = "ROBERTO LUIZ VIEIRA FILHO +++--+++ OMAR ZAGONEL EL LADEN +++--+++ ";
    uint32_t name_len;
    uint32_t sequence;
    uint32_t i;
    uint8_t  checksum_sw;
    uint8_t  char_wr;
    uint32_t handshake_cmd;
    uint32_t ctrl_status;
    uint8_t  seq_hw;
    uint8_t  checksum_hw;
    bool     match_hw;
    volatile uint8_t char_rd;

    name_len = strlen(name);
    sequence = 1;

    printf("\n==========================================================\n");
    printf("UTFPR - ELEW33 - Projeto BRAM + NIOS II + User HW\n");
    printf("Alunos: Roberto Luiz Vieira Filho & Omar Zagonel El Laden\n");
    printf("String: %s\n", name);
    printf("Tamanho: %u bytes\n", (unsigned int)name_len);
    printf("==========================================================\n");

    /* Reset inicial dos registradores e acumulador de checksum do HW */
    IOWR_32DIRECT(HW_BASE, CTRL_OFFSET, CHK_RST_BIT);
    delay(50);

    while (1)
    {
        /* ------------------------------------------------------------------ */
        /* 1) O SW deve fazer 1024 escritas na BRAM e calcular o Checksum SW  */
        /* ------------------------------------------------------------------ */
        checksum_sw = 0;
        for (i = 0; i < NUM_WR; i++)
        {
            char_wr = (uint8_t)name[i % name_len];
            write_byte(i, char_wr);
            checksum_sw += char_wr;
        }

        /* ------------------------------------------------------------------ */
        /* 2) Enviar o numero de sequencia e o checksum para o user_HW        */
        /*    Bits 31..24: Sequencia | Bits 23..16: Checksum SW               */
        /* ------------------------------------------------------------------ */
        handshake_cmd = ((sequence & 0xFF) << 24) | ((checksum_sw & 0xFF) << 16);
        IOWR_32DIRECT(HW_BASE, CTRL_OFFSET, handshake_cmd);

        delay(100); /* Aguarda comparacao no HW */

        /* ------------------------------------------------------------------ */
        /* 3) Ler resposta do user_HW (sequencia, checksum HW e match)        */
        /* ------------------------------------------------------------------ */
        ctrl_status = IORD_32DIRECT(HW_BASE, CTRL_OFFSET);
        seq_hw      = (ctrl_status >> 24) & 0xFF;
        checksum_hw = (ctrl_status >> 16) & 0xFF;
        match_hw    = (ctrl_status >> 7) & 0x01;

        /* ------------------------------------------------------------------ */
        /* 4) Enviar o numero de sequencia e o checksum para a UART           */
        /* ------------------------------------------------------------------ */
        printf("\n----------------------------------------------------------\n");
        printf("PACOTE %u ENVIADO (1024 BYTES):\n", (unsigned int)sequence);
        printf("Sequencia SW : %u | Sequencia HW : %u\n", (unsigned int)(sequence & 0xFF), (unsigned int)seq_hw);
        printf("Checksum  SW : 0x%02X | Checksum  HW : 0x%02X\n", checksum_sw, checksum_hw);
        printf("Status Match : %s\n", match_hw ? "SUCESSO (Match = TRUE)" : "FALHA (Match = FALSE)");

        /* ------------------------------------------------------------------ */
        /* 5) Validacao: Novo conjunto so deve ser enviado apos o recebimento */
        /*    do numero de sequencia e checksum corretos                      */
        /* ------------------------------------------------------------------ */
        if (!match_hw || (seq_hw != (sequence & 0xFF)) || (checksum_hw != checksum_sw))
        {
            printf("ERRO DE HANDSHAKE: Sequencia ou Checksum divergentes!\n");
        }
        else
        {
            printf("Handshake confirmado pelo User HW!\n");
        }

        /* ------------------------------------------------------------------ */
        /* 6) O SW deve fazer 1024 leituras da BRAM                           */
        /*    (para verificar o funcionamento, a string deve aparecer em READDATA) */
        /* ------------------------------------------------------------------ */
        printf("Lendo 1024 bytes da BRAM via READDATA:\n");
        for (i = 0; i < NUM_WR; i++)
        {
            char_rd = read_byte(i);
            printf("%c", char_rd);
        }
        printf("\n----------------------------------------------------------\n");

        /* ------------------------------------------------------------------ */
        /* 7) Prepara o User HW para o proximo conjunto de 1024 bytes         */
        /* ------------------------------------------------------------------ */
        IOWR_32DIRECT(HW_BASE, CTRL_OFFSET, CHK_RST_BIT);
        delay(50);

        sequence++;
        delay(200);
    }

    return 0;
}
