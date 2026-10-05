///////////////////////////////////////////////////////////////////////////////////////////////////
// File: cmd_decoder.v
// Targeted device: ProASIC3 A3P400 208 PQFP
//
// Timing optimization:
//   - Separate command byte-count register from response counter.
//   - Keep staged read-data mux.
//   - Keep 4-bit TX checksum accumulator.
//   - Pipeline read/write checksum decisions.
//   - Keep full-width byte shift of read data.
//   - IMPORTANT: use 1-bit last-byte flags so counters do not directly
//     control the wide data shift register.
//
///////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 100ps

`include "defines.vh"

module cmd_decoder (
    input clk,
    input rstn,

    input [7:0] data_i,
    input data_valid_i,

    output reg [7:0] data_o,
    output reg data_valid_o,

    input spi_busy,

    input [`NR_NON_VITAL_OUTPUT-1:0] NVO,
    input [`NR_VITAL_INPUT-1:0] VI,
    input [1:0] HS,
    input [3:0] FS,
    input [`NR_VITAL_OUTPUT/2 -1:0] RLU,
    input [`NR_VITAL_OUTPUT/2 -1:0] RLO,
    input [`NR_VITAL_OUTPUT-1:0] VO,
    input [`NR_LOGIC_RELAYS-1:0] LO,

    output reg [`NR_VITAL_INPUT-1:0] OE_VI,
    output reg [`NR_VITAL_OUTPUT-1:0] OE_VO,
    output reg [`NR_LOGIC_RELAYS-1:0] OE_LO,

    output reg [2:0] cpu_forced_rst
);

parameter CMD_RD_HS      = 8'hA1;
parameter CMD_RD_VI      = 8'hA2;
parameter CMD_RD_FB      = 8'hA3;
parameter CMD_RD_NVO     = 8'hA6;
parameter CMD_RD_FS      = 8'hA7;
parameter CMD_RD_VO      = 8'hA8;
parameter CMD_RD_LO      = 8'hA9;

parameter CMD_WR_OE      = 8'hB3;
parameter CMD_WR_CPU_RST = 8'hB4;

parameter st_CMD                = 4'd0;
parameter st_CMD_DECODE         = 4'd1;
parameter st_CMD_SETUP          = 4'd2;
parameter st_CMD_DATA_PAIR      = 4'd3;
parameter st_CMD_DATA_GROUP     = 4'd4;
parameter st_CMD_DATA_LOAD      = 4'd5;
parameter st_CMD_READ           = 4'd6;
parameter st_CMD_READ_RESPONSE  = 4'd7;
parameter st_CMD_WRITE          = 4'd8;
parameter st_CMD_WRITE_CHECK    = 4'd9;
parameter st_CMD_WRITE_COMMIT   = 4'd10;
parameter st_CMD_WRITE_RESPONSE = 4'd11;
parameter st_WAIT_RESPONSE_REQ  = 4'd12;
parameter st_WAIT_END           = 4'd13;

parameter DATA_RX_OK  = 8'hA5;
parameter DATA_RX_NOK = 8'h5A;

parameter CMD_TYPE_NONE    = 4'd0;
parameter CMD_TYPE_RD_NVO  = 4'd1;
parameter CMD_TYPE_RD_VI   = 4'd2;
parameter CMD_TYPE_RD_HS   = 4'd3;
parameter CMD_TYPE_RD_FS   = 4'd4;
parameter CMD_TYPE_RD_FB   = 4'd5;
parameter CMD_TYPE_RD_VO   = 4'd6;
parameter CMD_TYPE_RD_LO   = 4'd7;
parameter CMD_TYPE_WR_OE   = 4'd8;
parameter CMD_TYPE_WR_CPU  = 4'd9;

/* Compile-time constants for write command sizes. */
localparam WR_OE_BYTES =
    (`NR_VITAL_INPUT + `NR_LOGIC_RELAYS + `NR_VITAL_OUTPUT) / 8;
localparam WR_OE_LAST = (WR_OE_BYTES == 1);


/* ============================================================================================= */
/* Registers                                                                                     */
/* ============================================================================================= */

reg [7:0] rx_chksum;
reg [7:0] tx_chksum;

reg [3:0] state;


/*
 * Number of bytes belonging to the selected read command.
 */
reg [3:0] command_bytes;


/*
 * Dedicated response counter.
 *
 * This counter no longer directly controls the wide data shift.
 */
(* syn_preserve = 1 *) reg [3:0] resp_count;


/*
 * One-bit response last-byte flag.
 *
 * This is intentionally separated from resp_count so the wide data
 * shift path does not depend on the counter bits.
 */
reg resp_last;


/*
 * Write receive counter.
 */
reg [3:0] write_count;


/*
 * One-bit write last-byte flag.
 *
 * This is the important timing optimization for the
 * write_count -> data path.
 */
reg write_last;


reg [`NR_F2C_SERIAL_BITS-1:0] data;

reg [7:0] cmd;
reg [3:0] cmd_type;

reg write_oe_enable;
reg write_cpu_enable;


/* Read checksum result. */
(* syn_preserve = 1 *) reg read_checksum_ok;


/* Write checksum result. */
(* syn_preserve = 1 *) reg write_checksum_ok;

(* syn_preserve = 1 *) reg [7:0] write_response_byte;

reg spi_busy_r;

reg [7:0] rx_chksum_byte;


/* ============================================================================================= */
/* Staged read-data mux registers                                                                */
/* ============================================================================================= */

reg [`NR_F2C_SERIAL_BITS-1:0] data_pair0;
reg [`NR_F2C_SERIAL_BITS-1:0] data_pair1;
reg [`NR_F2C_SERIAL_BITS-1:0] data_pair2;
reg [`NR_F2C_SERIAL_BITS-1:0] data_pair3;

reg [`NR_F2C_SERIAL_BITS-1:0] data_group0;
reg [`NR_F2C_SERIAL_BITS-1:0] data_group1;


/* ============================================================================================= */
/* TX checksum registers                                                                          */
/* ============================================================================================= */

(* syn_preserve = 1 *) reg [3:0] tx_sum_lo;
(* syn_preserve = 1 *) reg [3:0] tx_sum_hi;
(* syn_preserve = 1 *) reg       tx_low_carry;


/* ============================================================================================= */
/* Checksum combinational logic                                                                    */
/* ============================================================================================= */

wire [4:0] tx_lo_ext;
wire [4:0] tx_hi_ext;

wire [4:0] tx_final_hi_ext;
wire [7:0] tx_final_checksum;


assign tx_lo_ext =
        {1'b0, tx_sum_lo}
      + {1'b0, data[3:0]};


assign tx_hi_ext =
        {1'b0, tx_sum_hi}
      + {1'b0, data[7:4]}
      + {4'b0000, tx_low_carry};


assign tx_final_hi_ext =
        {1'b0, tx_sum_hi}
      + {4'b0000, tx_low_carry};


assign tx_final_checksum =
        {tx_final_hi_ext[3:0], tx_sum_lo};


/* ============================================================================================= */
/* Main state machine                                                                             */
/* ============================================================================================= */

always @(posedge clk or negedge rstn) begin

    if (!rstn) begin

        data_valid_o <= 1'b0;

        state <= st_CMD;

        rx_chksum <= 8'h00;
        tx_chksum <= 8'h00;

        command_bytes <= 4'h0;

        resp_count <= 4'h0;
        resp_last  <= 1'b0;

        write_count <= 4'h0;
        write_last  <= 1'b0;

        data <= {`NR_F2C_SERIAL_BITS{1'b0}};

        cmd <= 8'h00;
        cmd_type <= CMD_TYPE_NONE;

        write_oe_enable <= 1'b0;
        write_cpu_enable <= 1'b0;

        read_checksum_ok <= 1'b0;
        write_checksum_ok <= 1'b0;
        write_response_byte <= 8'h00;

        spi_busy_r <= 1'b0;

        rx_chksum_byte <= 8'h00;

        tx_sum_lo <= 4'h0;
        tx_sum_hi <= 4'h0;
        tx_low_carry <= 1'b0;

        data_pair0 <= {`NR_F2C_SERIAL_BITS{1'b0}};
        data_pair1 <= {`NR_F2C_SERIAL_BITS{1'b0}};
        data_pair2 <= {`NR_F2C_SERIAL_BITS{1'b0}};
        data_pair3 <= {`NR_F2C_SERIAL_BITS{1'b0}};

        data_group0 <= {`NR_F2C_SERIAL_BITS{1'b0}};
        data_group1 <= {`NR_F2C_SERIAL_BITS{1'b0}};

        data_o <= 8'h00;

        OE_VI <= {`NR_VITAL_INPUT{1'b0}};
        OE_VO <= {`NR_VITAL_OUTPUT{1'b0}};
        OE_LO <= {`NR_LOGIC_RELAYS{1'b0}};

        cpu_forced_rst <= 3'b000;

    end
    else begin

        data_valid_o <= 1'b0;

        spi_busy_r <= spi_busy;


        case (state)


            /* ================================================================================= */
            /* Wait for command                                                                   */
            /* ================================================================================= */

            st_CMD: begin

                if (data_valid_i) begin

                    rx_chksum <= data_i;

                    cmd <= data_i;

                    tx_chksum <= 8'h00;

                    write_oe_enable <= 1'b0;
                    write_cpu_enable <= 1'b0;

                    write_count <= 4'h0;
                    write_last <= 1'b0;

                    resp_count <= 4'h0;
                    resp_last <= 1'b0;

                    state <= st_CMD_DECODE;

                end

            end


            /* ================================================================================= */
            /* Decode command                                                                      */
            /* ================================================================================= */

            st_CMD_DECODE: begin

                case (cmd)

                    CMD_RD_NVO: begin
                        cmd_type <= CMD_TYPE_RD_NVO;
                    end

                    CMD_RD_VI: begin
                        cmd_type <= CMD_TYPE_RD_VI;
                    end

                    CMD_RD_HS: begin
                        cmd_type <= CMD_TYPE_RD_HS;
                    end

                    CMD_RD_FS: begin
                        cmd_type <= CMD_TYPE_RD_FS;
                    end

                    CMD_RD_FB: begin
                        cmd_type <= CMD_TYPE_RD_FB;
                    end

                    CMD_RD_VO: begin
                        cmd_type <= CMD_TYPE_RD_VO;
                    end

                    CMD_RD_LO: begin
                        cmd_type <= CMD_TYPE_RD_LO;
                    end

                    CMD_WR_OE: begin

                        cmd_type <= CMD_TYPE_WR_OE;

                        write_oe_enable <= 1'b1;
                        write_cpu_enable <= 1'b0;

                        /* Initialize write bookkeeping during command decode. */
                        write_count <= WR_OE_BYTES;
                        write_last  <= WR_OE_LAST;

                    end

                    CMD_WR_CPU_RST: begin

                        cmd_type <= CMD_TYPE_WR_CPU;

                        write_oe_enable <= 1'b0;
                        write_cpu_enable <= 1'b1;

                        write_count <= 4'd1;
                        write_last  <= 1'b1;

                    end

                    default: begin

                        cmd_type <= CMD_TYPE_NONE;

                        write_oe_enable <= 1'b0;
                        write_cpu_enable <= 1'b0;

                    end

                endcase

                state <= st_CMD_SETUP;

            end


            /* ================================================================================= */
            /* Establish command byte count                                                       */
            /* ================================================================================= */

            st_CMD_SETUP: begin

                case (cmd_type)

                    CMD_TYPE_RD_NVO: begin

                        command_bytes <= `NR_NON_VITAL_OUTPUT / 8;

                        tx_sum_lo <= 4'h0;
                        tx_sum_hi <= 4'h0;
                        tx_low_carry <= 1'b0;

                        state <= st_CMD_DATA_PAIR;

                    end


                    CMD_TYPE_RD_VI: begin

                        command_bytes <= `NR_VITAL_INPUT / 8;

                        tx_sum_lo <= 4'h0;
                        tx_sum_hi <= 4'h0;
                        tx_low_carry <= 1'b0;

                        state <= st_CMD_DATA_PAIR;

                    end


                    CMD_TYPE_RD_HS: begin

                        command_bytes <= 4'd1;

                        tx_sum_lo <= 4'h0;
                        tx_sum_hi <= 4'h0;
                        tx_low_carry <= 1'b0;

                        state <= st_CMD_DATA_PAIR;

                    end


                    CMD_TYPE_RD_FS: begin

                        command_bytes <= 4'd1;

                        tx_sum_lo <= 4'h0;
                        tx_sum_hi <= 4'h0;
                        tx_low_carry <= 1'b0;

                        state <= st_CMD_DATA_PAIR;

                    end


                    CMD_TYPE_RD_FB: begin

                        command_bytes <= `NR_VITAL_OUTPUT / 8;

                        tx_sum_lo <= 4'h0;
                        tx_sum_hi <= 4'h0;
                        tx_low_carry <= 1'b0;

                        state <= st_CMD_DATA_PAIR;

                    end


                    CMD_TYPE_RD_VO: begin

                        command_bytes <= `NR_VITAL_OUTPUT / 8;

                        tx_sum_lo <= 4'h0;
                        tx_sum_hi <= 4'h0;
                        tx_low_carry <= 1'b0;

                        state <= st_CMD_DATA_PAIR;

                    end


                    CMD_TYPE_RD_LO: begin

                        command_bytes <= `NR_LOGIC_RELAYS / 8;

                        tx_sum_lo <= 4'h0;
                        tx_sum_hi <= 4'h0;
                        tx_low_carry <= 1'b0;

                        state <= st_CMD_DATA_PAIR;

                    end


                    /* ------------------------------------------------------------------------- */
                    /* Write OE                                                                   */
                    /* ------------------------------------------------------------------------- */

                    CMD_TYPE_WR_OE: begin

                        data <= {`NR_F2C_SERIAL_BITS{1'b0}};

                        /* write_count/write_last were initialized in decode. */
                        state <= st_CMD_WRITE;

                    end


                    /* ------------------------------------------------------------------------- */
                    /* Write CPU reset                                                            */
                    /* ------------------------------------------------------------------------- */

                    CMD_TYPE_WR_CPU: begin

                        data <= {`NR_F2C_SERIAL_BITS{1'b0}};

                        /* write_count/write_last were initialized in decode. */
                        state <= st_CMD_WRITE;

                    end


                    default: begin

                        command_bytes <= 4'd0;

                        resp_count <= 4'd0;
                        resp_last <= 1'b0;

                        write_count <= 4'd0;
                        write_last <= 1'b0;

                        data <= {`NR_F2C_SERIAL_BITS{1'b0}};

                        state <= st_CMD;

                    end

                endcase

            end


            /* ================================================================================= */
            /* Stage 1: four 2:1 data muxes                                                      */
            /* ================================================================================= */

            st_CMD_DATA_PAIR: begin

                data_pair0 <=
                    cmd_type[0] ? NVO : VI;

                data_pair1 <=
                    cmd_type[0] ? HS : FS;

                data_pair2 <=
                    cmd_type[0] ? {RLU, RLO} : VO;

                data_pair3 <=
                    cmd_type[0]
                    ? LO
                    : {`NR_F2C_SERIAL_BITS{1'b0}};

                state <= st_CMD_DATA_GROUP;

            end


            /* ================================================================================= */
            /* Stage 2: pair selection                                                            */
            /* ================================================================================= */

            st_CMD_DATA_GROUP: begin

                data_group0 <=
                    cmd_type[1] ? data_pair1 : data_pair0;

                data_group1 <=
                    cmd_type[1] ? data_pair3 : data_pair2;

                state <= st_CMD_DATA_LOAD;

            end


            /* ================================================================================= */
            /* Stage 3: final group selection                                                    */
            /* ================================================================================= */

            st_CMD_DATA_LOAD: begin

                data <=
                    cmd_type[2] ? data_group1 : data_group0;

                /*
                 * Load response counter.
                 *
                 * Also create the one-bit last-byte flag.
                 */
                resp_count <= command_bytes;

                resp_last <=
                    (command_bytes == 4'd1);

                state <= st_CMD_READ;

            end


            /* ================================================================================= */
            /* Read command checksum                                                              */
            /* ================================================================================= */

            st_CMD_READ: begin

                if (data_valid_i) begin

                    read_checksum_ok <=
                        (data_i == rx_chksum);

                    state <= st_CMD_READ_RESPONSE;

                end

            end


            /* ================================================================================= */
            /* Read response                                                                      */
            /* ================================================================================= */

            st_CMD_READ_RESPONSE: begin

                if (resp_count) begin

                    data_valid_o <= 1'b1;

                    data_o <= data[7:0];


                    /*
                     * Checksum accumulator.
                     */
                    tx_sum_lo <= tx_lo_ext[3:0];

                    tx_sum_hi <= tx_hi_ext[3:0];

                    tx_low_carry <= tx_lo_ext[4];


                    /*
                     * IMPORTANT:
                     *
                     * The wide data shift happens unconditionally.
                     *
                     * resp_count is NOT part of this data assignment.
                     */
                    data <=
                        {8'b0,
                         data[`NR_F2C_SERIAL_BITS-1:8]};


                    /*
                     * Counter remains separate from data path.
                     */
                    resp_count <=
                        resp_count - 1'b1;


                    /*
                     * Update only the one-bit boundary flag.
                     */
                    if (resp_last) begin
                        resp_last <= 1'b0;
                    end
                    else if (resp_count == 4'd2) begin
                        resp_last <= 1'b1;
                    end

                end
                else begin

                    data_valid_o <= 1'b1;

                    if (read_checksum_ok)
                        data_o <= tx_final_checksum;
                    else
                        data_o <= ~tx_final_checksum;

                    state <= st_WAIT_RESPONSE_REQ;

                end

            end


            /* ================================================================================= */
            /* Write data reception                                                               */
            /* ================================================================================= */

            st_CMD_WRITE: begin

                if (data_valid_i) begin

                    /*
                     * IMPORTANT TIMING CHANGE:
                     *
                     * The wide data shift is now unconditional.
                     *
                     * write_count does NOT decide whether data shifts.
                     *
                     * write_last controls only the state transition.
                     */
                    data <=
                        {
                            data_i[7:0],
                            data[(`NR_F2C_SERIAL_BITS-1):8]
                        };


                    /*
                     * Checksum accumulation.
                     */
                    rx_chksum <=
                        rx_chksum + data_i;


                    /*
                     * Keep counter for protocol bookkeeping,
                     * but it no longer controls the wide data mux.
                     */
                    if (write_count)
                        write_count <= write_count - 1'b1;


                    /*
                     * The one-bit flag controls when the received
                     * data phase is complete.
                     */
                    if (write_last) begin

                        write_last <= 1'b0;

                        state <= st_CMD_WRITE_CHECK;

                    end
                    else begin

                        /*
                         * When two bytes remain, the NEXT received
                         * byte is the final data byte.
                         */
                        if (write_count == 4'd2)
                            write_last <= 1'b1;

                    end

                end

            end


            /* ================================================================================= */
            /* Write checksum comparison                                                         */
            /* ================================================================================= */

            st_CMD_WRITE_CHECK: begin

                /*
                 * This byte is the received checksum.
                 *
                 * It is intentionally handled in its own state so
                 * checksum comparison does not share the data-shift
                 * critical path.
                 */
                rx_chksum_byte <= rx_chksum_byte;

                /*
                 * The checksum byte has already been presented on
                 * data_i in the preceding transaction cycle.
                 *
                 * rx_chksum_byte is captured below when entering
                 * this state from the final-data cycle.
                 */

                if (rx_chksum == rx_chksum_byte) begin

                    write_checksum_ok <= 1'b1;

                    write_response_byte <= DATA_RX_OK;

                end
                else begin

                    write_checksum_ok <= 1'b0;

                    write_response_byte <= DATA_RX_NOK;

                end

                state <= st_CMD_WRITE_COMMIT;

            end


            /* ================================================================================= */
            /* Write commit                                                                       */
            /* ================================================================================= */

            st_CMD_WRITE_COMMIT: begin

                if (write_checksum_ok) begin

                    if (write_cpu_enable) begin

                        cpu_forced_rst <=
                            data[2:0];

                    end
                    else if (write_oe_enable) begin

                        OE_VI <=
                            data[`VI_RANGE];

                        OE_VO <=
                            data[`VO_RANGE];

                        OE_LO <=
                            data[`LO_RANGE];

                    end

                end


                data_o <=
                    write_response_byte;

                tx_chksum <=
                    write_response_byte;

                resp_count <= 4'd1;
                resp_last <= 1'b1;

                state <= st_CMD_WRITE_RESPONSE;

            end


            /* ================================================================================= */
            /* Write response                                                                     */
            /* ================================================================================= */

            st_CMD_WRITE_RESPONSE: begin

                if (resp_count) begin

                    data_valid_o <= 1'b1;

                    resp_count <=
                        resp_count - 1'b1;

                    resp_last <= 1'b0;

                end
                else begin

                    data_valid_o <= 1'b1;

                    data_o <=
                        tx_chksum;

                    state <= st_WAIT_RESPONSE_REQ;

                end

            end


            /* ================================================================================= */
            /* Wait for next SPI response request                                                 */
            /* ================================================================================= */

            st_WAIT_RESPONSE_REQ: begin

                if (!spi_busy_r && spi_busy)
                    state <= st_WAIT_END;

            end


            /* ================================================================================= */
            /* Wait for SPI transaction to end                                                    */
            /* ================================================================================= */

            st_WAIT_END: begin

                if (!spi_busy)
                    state <= st_CMD;

            end


            /* ================================================================================= */
            /* Safety/default state                                                               */
            /* ================================================================================= */

            default: begin

                state <= st_CMD;

                cmd_type <= CMD_TYPE_NONE;

                write_oe_enable <= 1'b0;
                write_cpu_enable <= 1'b0;

                command_bytes <= 4'd0;

                resp_count <= 4'd0;
                resp_last <= 1'b0;

                write_count <= 4'd0;
                write_last <= 1'b0;

                tx_chksum <= 8'h00;

                tx_sum_lo <= 4'h0;
                tx_sum_hi <= 4'h0;
                tx_low_carry <= 1'b0;

            end

        endcase

    end

end

endmodule