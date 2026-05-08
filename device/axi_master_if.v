module axi_master_if #(
    parameter ID_WIDTH = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input                       ACLK_i,
    input                       ARESETn_i,

    //================ Control ======================//
    input  [4:0]                m_address_memory,
    input                       m_READ_EN,
    input  [DATA_WIDTH-1:0]     m_DATA_MEMORY_i,
    input                       m_WRITE_EN,
    output [DATA_WIDTH-1:0]     m_DATA_MEMORY_o,
    
    input                       ReadTrans_EN_i,
    input  [4:0]                set_addr_memory,   //chon dia chi lua gia tri tu slave tra ve
    input  [ADDR_WIDTH-1:0]     set_ARADDR_i,
    input  [1:0]                set_ARBURST_i,
    input  [7:0]                set_ARLEN_i,
    input  [2:0]                set_ARSIZE_i,

    input                       WriteTrans_EN_i,	

    //================ WRITE ADDRESS =================//
    output 		                 m_AWVALID_o,
    output [ID_WIDTH-1:0]       m_AWID_o,
    output [ADDR_WIDTH-1:0]     m_AWADDR_o,
    output [1:0]                m_AWBURST_o,
    output [7:0]                m_AWLEN_o,
    output [2:0]                m_AWSIZE_o,
    input                       m_AWREADY_i,

    //================ WRITE DATA ====================//
    output                      m_WVALID_o,
    output [DATA_WIDTH-1:0]     m_WDATA_o,
    output                      m_WLAST_o,
    input                       m_WREADY_i,

    //================ WRITE RESP ====================//
    input                       m_BVALID_i,
    input  [ID_WIDTH-1:0]       m_BID_i,
    input  [1:0]                m_BRESP_i,
    output                      m_BREADY_o,

    //================ READ ADDRESS ==================//
    output                      m_ARVALID_o,
    output [ID_WIDTH-1:0]       m_ARID_o,
    output [ADDR_WIDTH-1:0]     m_ARADDR_o,
    output [1:0]                m_ARBURST_o,
    output [7:0]                m_ARLEN_o,
    output [2:0]                m_ARSIZE_o,
    input                       m_ARREADY_i,

    //================ READ DATA =====================//
    input                       m_RVALID_i,
    input                       m_RLAST_i,
    input  [ID_WIDTH-1:0]       m_RID_i,
    input  [DATA_WIDTH-1:0]     m_RDATA_i,
    input  [1:0]                m_RRESP_i,
    output                      m_RREADY_o
);

    //================ MEMORY =================//
	 //doc du lieu memory tu master de kiem tra xem co du lieu hay khong
    reg [DATA_WIDTH-1:0] mem [0:31];

    assign DATA_MEMORY_o = (m_READ_EN) ? mem[m_address_memory] : 0;

    always @(posedge ACLK_i)
        if (m_WRITE_EN)
            mem[m_address_memory] <= m_DATA_MEMORY_i;

    //================ INTERNAL =================//
    reg [4:0] mem_ptr;
    reg [7:0] burst_cnt;

    reg [2:0] state, next_state;

    localparam IDLE  = 3'd0,
               AR    = 3'd1,
               RDATA = 3'd2,
               AW    = 3'd3,
               WDATA = 3'd4,
               BRESP = 3'd5;

    //================ STATE =================//
    always @(posedge ACLK_i or negedge ARESETn_i)
        if (!ARESETn_i) state <= IDLE;
        else state <= next_state;

    //================ NEXT STATE =================//
    always @(*) begin
        case(state)
        IDLE:
            if (ReadTrans_EN_i) next_state = AR;
            else if (WriteTrans_EN_i) next_state = AW;
            else next_state = IDLE;

        AR:
            if (m_ARVALID_o && m_ARREADY_i) next_state = RDATA;
            else next_state = AR;

        RDATA:
            if (m_RVALID_i && m_RREADY_o && m_RLAST_i)
                next_state = IDLE;
            else
                next_state = RDATA;

        AW:
            if (m_AWVALID_o && m_AWREADY_i) next_state = WDATA;
            else next_state = AW;

        WDATA:
            if (m_WVALID_o && m_WREADY_i && m_WLAST_o)
                next_state = BRESP;
            else
                next_state = WDATA;

        BRESP:
            if (m_BVALID_i && m_BREADY_o)
                next_state = IDLE;
            else
                next_state = BRESP;

        default: next_state = IDLE;
        endcase
    end

    //================ POINTER + BURST =================//
    always @(posedge ACLK_i or negedge ARESETn_i) begin
        if (!ARESETn_i) begin
            mem_ptr <= 0;
            burst_cnt <= 0;
        end else begin
            case(state)

            AR:
                if (m_ARVALID_o && m_ARREADY_i) begin
                    mem_ptr <= set_addr_memory;         //chon dia chi muon nhan du lieu tu slave
                    burst_cnt <= 0;							//dem so burst
                end

            RDATA:
                if (m_RVALID_i && m_RREADY_o) begin
                    mem[mem_ptr] <= m_RDATA_i;
                    mem_ptr <= mem_ptr + 1;
                    burst_cnt <= burst_cnt + 1;
                end

            AW:
                if (m_AWVALID_o && m_AWREADY_i) begin
                    mem_ptr <= set_addr_memory;
                    burst_cnt <= 0;
                end

            WDATA:
                if (m_WVALID_o && m_WREADY_i) begin
                    mem_ptr <= mem_ptr + 1;
                    burst_cnt <= burst_cnt + 1;
                end

            default: ;
            endcase
        end
    end

    //================ OUTPUT =================//

    // READ ADDRESS
    assign m_ARVALID_o = (state == AR);
    assign m_ARADDR_o  = set_ARADDR_i;
    assign m_ARBURST_o = set_ARBURST_i;
    assign m_ARLEN_o   = set_ARLEN_i;
    assign m_ARSIZE_o  = set_ARSIZE_i;
    assign m_ARID_o    = 0;

    // READ DATA
    assign m_RREADY_o = (state == RDATA);

    // WRITE ADDRESS
    assign m_AWVALID_o = (state == AW) ? 2'b11 : 2'b00; // giữ nguyên width
    assign m_AWADDR_o  = set_ARADDR_i;
    assign m_AWBURST_o = set_ARBURST_i;
    assign m_AWLEN_o   = set_ARLEN_i;
    assign m_AWSIZE_o  = set_ARSIZE_i;
    assign m_AWID_o    = 0;

    // WRITE DATA
    assign m_WVALID_o = (state == WDATA);
    assign m_WDATA_o  = mem[mem_ptr];
    assign m_WLAST_o  = (burst_cnt == set_ARLEN_i);

    // WRITE RESP
    assign m_BREADY_o = (state == BRESP);

endmodule