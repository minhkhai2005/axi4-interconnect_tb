`timescale 1ns/1ps

module tb_axi_interconnect();

    // =========================================================================
    // 1. PARAMETERS DEFINITION
    // =========================================================================
    parameter MST_AMT           = 2; // Thay đổi số lượng master ở đây
    parameter SLV_AMT           = 3; // Thay đổi số lượng slave ở đây
    parameter OUTSTANDING_AMT   = 8; // Số lượng outstanding transaction cho phép.
    parameter [0:(MST_AMT*32)-1] MST_WEIGHT = {32'd2, 32'd1};
    
    parameter DATA_WIDTH        = 32; // độ rộng bus dữ liệu
    parameter ADDR_WIDTH        = 32; // độ rộng bus địa chỉ
    parameter TRANS_MST_ID_W    = 5; // độ rộng bus ID của master 
    parameter MST_ID_W          = $clog2(MST_AMT);
    parameter TRANS_SLV_ID_W    = TRANS_MST_ID_W + MST_ID_W;
    parameter TRANS_BURST_W     = 2;
    parameter TRANS_DATA_LEN_W  = 8;
    parameter TRANS_DATA_SIZE_W = 3;
    parameter TRANS_WR_RESP_W   = 2;

    // RAM
    parameter RAM_SIZE          = 128;
    parameter RAM_ADDR_WIDTH    = $clog2(RAM_SIZE);

    // =========================================================================
    // 2. CLOCK & RESET
    // =========================================================================
    reg ACLK;
    reg ARESETn;

    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK; // Chu kỳ 10ns (100MHz)
    end

    initial begin
        ARESETn = 0;
        #20;
        ARESETn = 1;
    end

    // =========================================================================
    // 3. MASTER CONTROL SIGNALS (Arrays of reg)
    // =========================================================================
    reg [RAM_ADDR_WIDTH-1:0]            mst_address_memory   [0:MST_AMT-1];
    reg                  mst_READ_EN          [0:MST_AMT-1];
    reg [DATA_WIDTH-1:0] mst_DATA_MEMORY_i    [0:MST_AMT-1];
    reg                  mst_WRITE_EN         [0:MST_AMT-1];
    wire [DATA_WIDTH-1:0]mst_DATA_MEMORY_o    [0:MST_AMT-1]; // Output từ master là wire
    
    reg                  mst_ReadTrans_EN_i   [0:MST_AMT-1];
    reg [RAM_ADDR_WIDTH-1:0]            mst_r_set_addr_memory[0:MST_AMT-1];
    reg [ADDR_WIDTH-1:0] mst_set_ARADDR_i     [0:MST_AMT-1];
    reg [1:0]            mst_set_ARBURST_i    [0:MST_AMT-1];
    reg [7:0]            mst_set_ARLEN_i      [0:MST_AMT-1];
    reg [2:0]            mst_set_ARSIZE_i     [0:MST_AMT-1];
    
    reg                  mst_WriteTrans_EN_i  [0:MST_AMT-1];
    reg [RAM_ADDR_WIDTH-1:0]            mst_w_set_addr_memory[0:MST_AMT-1];
    reg [ADDR_WIDTH-1:0] mst_set_AWADDR_i     [0:MST_AMT-1];
    reg [1:0]            mst_set_AWBURST_i    [0:MST_AMT-1];
    reg [7:0]            mst_set_AWLEN_i      [0:MST_AMT-1];
    reg [2:0]            mst_set_AWSIZE_i     [0:MST_AMT-1];

    integer i_mst;
    initial begin
        for(i_mst = 0; i_mst < MST_AMT; i_mst = i_mst + 1) begin
            mst_address_memory[i_mst]    = 0;
            mst_READ_EN[i_mst]           = 0;
            mst_DATA_MEMORY_i[i_mst]     = 0;
            mst_WRITE_EN[i_mst]          = 0;
            mst_ReadTrans_EN_i[i_mst]    = 0;
            mst_WriteTrans_EN_i[i_mst]   = 0;
        end
    end

    // =========================================================================
    // 4. SLAVE CONTROL SIGNALS
    // =========================================================================
    reg [RAM_ADDR_WIDTH-1:0]                  slv_address_memory   [0:SLV_AMT-1];
    reg [DATA_WIDTH-1:0] slv_DATA_MEMORY_i    [0:SLV_AMT-1];
    reg                  slv_WRITE_EN         [0:SLV_AMT-1];

    integer i_slv;
    initial begin
        for(i_slv = 0; i_slv < SLV_AMT; i_slv = i_slv + 1) begin
            slv_address_memory[i_slv] = 0;
            slv_DATA_MEMORY_i[i_slv]  = 0;
            slv_WRITE_EN[i_slv]       = 0;
        end
    end

    // =========================================================================
    // 5. FLATTENED AXI BUSES (Connecting Interconnect and Devices)
    // =========================================================================
    // Các đường bus này dùng để đấu nối structural nên bắt buộc là wire
    wire [TRANS_MST_ID_W*MST_AMT-1:0]    m_AWID;
    wire [ADDR_WIDTH*MST_AMT-1:0]        m_AWADDR;
    wire [TRANS_BURST_W*MST_AMT-1:0]     m_AWBURST;
    wire [TRANS_DATA_LEN_W*MST_AMT-1:0]  m_AWLEN;
    wire [TRANS_DATA_SIZE_W*MST_AMT-1:0] m_AWSIZE;
    wire [MST_AMT-1:0]                   m_AWVALID;
    wire [MST_AMT-1:0]                   m_AWREADY;
    wire [DATA_WIDTH*MST_AMT-1:0]        m_WDATA;
    wire [MST_AMT-1:0]                   m_WLAST;
    wire [MST_AMT-1:0]                   m_WVALID;
    wire [MST_AMT-1:0]                   m_WREADY;
    wire [TRANS_MST_ID_W*MST_AMT-1:0]    m_BID;
    wire [TRANS_WR_RESP_W*MST_AMT-1:0]   m_BRESP;
    wire [MST_AMT-1:0]                   m_BVALID;
    wire [MST_AMT-1:0]                   m_BREADY;
    wire [TRANS_MST_ID_W*MST_AMT-1:0]    m_ARID;
    wire [ADDR_WIDTH*MST_AMT-1:0]        m_ARADDR;
    wire [TRANS_BURST_W*MST_AMT-1:0]     m_ARBURST;
    wire [TRANS_DATA_LEN_W*MST_AMT-1:0]  m_ARLEN;
    wire [TRANS_DATA_SIZE_W*MST_AMT-1:0] m_ARSIZE;
    wire [MST_AMT-1:0]                   m_ARVALID;
    wire [MST_AMT-1:0]                   m_ARREADY;
    wire [TRANS_MST_ID_W*MST_AMT-1:0]    m_RID;
    wire [DATA_WIDTH*MST_AMT-1:0]        m_RDATA;
    wire [TRANS_WR_RESP_W*MST_AMT-1:0]   m_RRESP;
    wire [MST_AMT-1:0]                   m_RLAST;
    wire [MST_AMT-1:0]                   m_RVALID;
    wire [MST_AMT-1:0]                   m_RREADY;

    // Slave
    wire [TRANS_SLV_ID_W*SLV_AMT-1:0]    s_AWID;
    wire [ADDR_WIDTH*SLV_AMT-1:0]        s_AWADDR;
    wire [TRANS_BURST_W*SLV_AMT-1:0]     s_AWBURST;
    wire [TRANS_DATA_LEN_W*SLV_AMT-1:0]  s_AWLEN;
    wire [TRANS_DATA_SIZE_W*SLV_AMT-1:0] s_AWSIZE;
    wire [SLV_AMT-1:0]                   s_AWVALID;
    wire [SLV_AMT-1:0]                   s_AWREADY;
    wire [DATA_WIDTH*SLV_AMT-1:0]        s_WDATA;
    wire [SLV_AMT-1:0]                   s_WLAST;
    wire [SLV_AMT-1:0]                   s_WVALID;
    wire [SLV_AMT-1:0]                   s_WREADY;
    wire [TRANS_SLV_ID_W*SLV_AMT-1:0]    s_BID;
    wire [TRANS_WR_RESP_W*SLV_AMT-1:0]   s_BRESP;
    wire [SLV_AMT-1:0]                   s_BVALID;
    wire [SLV_AMT-1:0]                   s_BREADY;
    wire [TRANS_SLV_ID_W*SLV_AMT-1:0]    s_ARID;
    wire [ADDR_WIDTH*SLV_AMT-1:0]        s_ARADDR;
    wire [TRANS_BURST_W*SLV_AMT-1:0]     s_ARBURST;
    wire [TRANS_DATA_LEN_W*SLV_AMT-1:0]  s_ARLEN;
    wire [TRANS_DATA_SIZE_W*SLV_AMT-1:0] s_ARSIZE;
    wire [SLV_AMT-1:0]                   s_ARVALID;
    wire [SLV_AMT-1:0]                   s_ARREADY;
    wire [TRANS_SLV_ID_W*SLV_AMT-1:0]    s_RID;
    wire [DATA_WIDTH*SLV_AMT-1:0]        s_RDATA;
    wire [TRANS_WR_RESP_W*SLV_AMT-1:0]   s_RRESP;
    wire [SLV_AMT-1:0]                   s_RLAST;
    wire [SLV_AMT-1:0]                   s_RVALID;
    wire [SLV_AMT-1:0]                   s_RREADY;

    // =========================================================================
    // 6. GENERATE MASTERS & SLAVES
    // =========================================================================
    genvar g_idx;
    generate
        // Tạo các Master
        for(g_idx = 0; g_idx < MST_AMT; g_idx = g_idx + 1) begin : GEN_MASTERS
            axi_master_if #(
                .ID_WIDTH(TRANS_MST_ID_W),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) u_master (
                .ACLK_i(ACLK),
                .ARESETn_i(ARESETn),
                
                // Master Control (Verilog-2001 array indexing)
                .m_address_memory(mst_address_memory[g_idx]),
                .m_READ_EN(mst_READ_EN[g_idx]),
                .m_DATA_MEMORY_i(mst_DATA_MEMORY_i[g_idx]),
                .m_WRITE_EN(mst_WRITE_EN[g_idx]),
                .m_DATA_MEMORY_o(mst_DATA_MEMORY_o[g_idx]),
                
                .ReadTrans_EN_i(mst_ReadTrans_EN_i[g_idx]),
                .r_set_addr_memory(mst_r_set_addr_memory[g_idx]),
                .set_ARADDR_i(mst_set_ARADDR_i[g_idx]),
                .set_ARBURST_i(mst_set_ARBURST_i[g_idx]),
                .set_ARLEN_i(mst_set_ARLEN_i[g_idx]),
                .set_ARSIZE_i(mst_set_ARSIZE_i[g_idx]),
                
                .WriteTrans_EN_i(mst_WriteTrans_EN_i[g_idx]),
                .w_set_addr_memory(mst_w_set_addr_memory[g_idx]),
                .set_AWADDR_i(mst_set_AWADDR_i[g_idx]),
                .set_AWBURST_i(mst_set_AWBURST_i[g_idx]),
                .set_AWLEN_i(mst_set_AWLEN_i[g_idx]),
                .set_AWSIZE_i(mst_set_AWSIZE_i[g_idx]),
                
                // Nối Bus phẳng (Sử dụng toán tử -: của Verilog 2001)
                .m_AWVALID_o(m_AWVALID[g_idx]),
                .m_AWID_o   (m_AWID[TRANS_MST_ID_W*(g_idx+1)-1 -: TRANS_MST_ID_W]),
                .m_AWADDR_o (m_AWADDR[ADDR_WIDTH*(g_idx+1)-1 -: ADDR_WIDTH]),
                .m_AWBURST_o(m_AWBURST[TRANS_BURST_W*(g_idx+1)-1 -: TRANS_BURST_W]),
                .m_AWLEN_o  (m_AWLEN[TRANS_DATA_LEN_W*(g_idx+1)-1 -: TRANS_DATA_LEN_W]),
                .m_AWSIZE_o (m_AWSIZE[TRANS_DATA_SIZE_W*(g_idx+1)-1 -: TRANS_DATA_SIZE_W]),
                .m_AWREADY_i(m_AWREADY[g_idx]),
                
                .m_WVALID_o (m_WVALID[g_idx]),
                .m_WDATA_o  (m_WDATA[DATA_WIDTH*(g_idx+1)-1 -: DATA_WIDTH]),
                .m_WLAST_o  (m_WLAST[g_idx]),
                .m_WREADY_i (m_WREADY[g_idx]),
                
                .m_BVALID_i (m_BVALID[g_idx]),
                .m_BID_i    (m_BID[TRANS_MST_ID_W*(g_idx+1)-1 -: TRANS_MST_ID_W]),
                .m_BRESP_i  (m_BRESP[TRANS_WR_RESP_W*(g_idx+1)-1 -: TRANS_WR_RESP_W]),
                .m_BREADY_o (m_BREADY[g_idx]),
                
                .m_ARVALID_o(m_ARVALID[g_idx]),
                .m_ARID_o   (m_ARID[TRANS_MST_ID_W*(g_idx+1)-1 -: TRANS_MST_ID_W]),
                .m_ARADDR_o (m_ARADDR[ADDR_WIDTH*(g_idx+1)-1 -: ADDR_WIDTH]),
                .m_ARBURST_o(m_ARBURST[TRANS_BURST_W*(g_idx+1)-1 -: TRANS_BURST_W]),
                .m_ARLEN_o  (m_ARLEN[TRANS_DATA_LEN_W*(g_idx+1)-1 -: TRANS_DATA_LEN_W]),
                .m_ARSIZE_o (m_ARSIZE[TRANS_DATA_SIZE_W*(g_idx+1)-1 -: TRANS_DATA_SIZE_W]),
                .m_ARREADY_i(m_ARREADY[g_idx]),
                
                .m_RVALID_i (m_RVALID[g_idx]),
                .m_RLAST_i  (m_RLAST[g_idx]),
                .m_RID_i    (m_RID[TRANS_MST_ID_W*(g_idx+1)-1 -: TRANS_MST_ID_W]),
                .m_RDATA_i  (m_RDATA[DATA_WIDTH*(g_idx+1)-1 -: DATA_WIDTH]),
                .m_RRESP_i  (m_RRESP[TRANS_WR_RESP_W*(g_idx+1)-1 -: TRANS_WR_RESP_W]),
                .m_RREADY_o (m_RREADY[g_idx])
            );
        end

        // Tạo các Slave
        for(g_idx = 0; g_idx < SLV_AMT; g_idx = g_idx + 1) begin : GEN_SLAVES
            axi_slave_if #(
                .ID_WIDTH(TRANS_SLV_ID_W),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) u_slave (
                .ACLK_i(ACLK),
                .ARESETn_i(ARESETn),
                
                // Slave Control
                .s_address_memory(slv_address_memory[g_idx]),
                .s_DATA_MEMORY_i(slv_DATA_MEMORY_i[g_idx]),
                .s_WRITE_EN(slv_WRITE_EN[g_idx]),

                .s_AWVALID_i(s_AWVALID[g_idx]),
                .s_AWID_i   (s_AWID[TRANS_SLV_ID_W*(g_idx+1)-1 -: TRANS_SLV_ID_W]),
                .s_AWADDR_i (s_AWADDR[ADDR_WIDTH*(g_idx+1)-1 -: ADDR_WIDTH]),
                .s_AWLEN_i  (s_AWLEN[TRANS_DATA_LEN_W*(g_idx+1)-1 -: TRANS_DATA_LEN_W]),
                .s_AWREADY_o(s_AWREADY[g_idx]),
                
                .s_WVALID_i (s_WVALID[g_idx]),
                .s_WDATA_i  (s_WDATA[DATA_WIDTH*(g_idx+1)-1 -: DATA_WIDTH]),
                .s_WLAST_i  (s_WLAST[g_idx]),
                .s_WREADY_o (s_WREADY[g_idx]),
                
                .s_BVALID_o (s_BVALID[g_idx]),
                .s_BID_o    (s_BID[TRANS_SLV_ID_W*(g_idx+1)-1 -: TRANS_SLV_ID_W]),
                .s_BRESP_o  (s_BRESP[TRANS_WR_RESP_W*(g_idx+1)-1 -: TRANS_WR_RESP_W]),
                .s_BREADY_i (s_BREADY[g_idx]),
                
                .s_ARVALID_i(s_ARVALID[g_idx]),
                .s_ARID_i   (s_ARID[TRANS_SLV_ID_W*(g_idx+1)-1 -: TRANS_SLV_ID_W]),
                .s_ARADDR_i (s_ARADDR[ADDR_WIDTH*(g_idx+1)-1 -: ADDR_WIDTH]),
                .s_ARLEN_i  (s_ARLEN[TRANS_DATA_LEN_W*(g_idx+1)-1 -: TRANS_DATA_LEN_W]),
                .s_ARREADY_o(s_ARREADY[g_idx]),
                
                .s_RVALID_o (s_RVALID[g_idx]),
                .s_RLAST_o  (s_RLAST[g_idx]),
                .s_RID_o    (s_RID[TRANS_SLV_ID_W*(g_idx+1)-1 -: TRANS_SLV_ID_W]),
                .s_RDATA_o  (s_RDATA[DATA_WIDTH*(g_idx+1)-1 -: DATA_WIDTH]),
                .s_RRESP_o  (s_RRESP[TRANS_WR_RESP_W*(g_idx+1)-1 -: TRANS_WR_RESP_W]),
                .s_RREADY_i (s_RREADY[g_idx])
            );
        end
    endgenerate

    // =========================================================================
    // 7. AXI INTERCONNECT INSTANTIATION
    // =========================================================================
    axi_interconnect #(
        .MST_AMT(MST_AMT),
        .SLV_AMT(SLV_AMT),
        .OUTSTANDING_AMT(OUTSTANDING_AMT),
        .MST_WEIGHT(MST_WEIGHT),
        .TRANS_DATA_LEN_W(TRANS_DATA_LEN_W),
        .TRANS_DATA_SIZE_W(TRANS_DATA_SIZE_W)
    ) u_interconnect (
        .ACLK_i     (ACLK),
        .ARESETn_i  (ARESETn),
        
        .m_AWID_i   (m_AWID),   .m_AWADDR_i (m_AWADDR), .m_AWBURST_i(m_AWBURST),
        .m_AWLEN_i  (m_AWLEN),  .m_AWSIZE_i (m_AWSIZE), .m_AWVALID_i(m_AWVALID),
        .m_WDATA_i  (m_WDATA),  .m_WLAST_i  (m_WLAST),  .m_WVALID_i (m_WVALID),
        .m_BREADY_i (m_BREADY),
        .m_ARID_i   (m_ARID),   .m_ARADDR_i (m_ARADDR), .m_ARBURST_i(m_ARBURST),
        .m_ARLEN_i  (m_ARLEN),  .m_ARSIZE_i (m_ARSIZE), .m_ARVALID_i(m_ARVALID),
        .m_RREADY_i (m_RREADY),
        
        .m_AWREADY_o(m_AWREADY),.m_WREADY_o (m_WREADY), .m_BID_o    (m_BID),
        .m_BRESP_o  (m_BRESP),  .m_BVALID_o (m_BVALID), .m_ARREADY_o(m_ARREADY),
        .m_RID_o    (m_RID),    .m_RDATA_o  (m_RDATA),  .m_RRESP_o  (m_RRESP),
        .m_RLAST_o  (m_RLAST),  .m_RVALID_o (m_RVALID),
        
        .s_AWREADY_i(s_AWREADY),.s_WREADY_i (s_WREADY), .s_BID_i    (s_BID),
        .s_BRESP_i  (s_BRESP),  .s_BVALID_i (s_BVALID), .s_ARREADY_i(s_ARREADY),
        .s_RID_i    (s_RID),    .s_RDATA_i  (s_RDATA),  .s_RRESP_i  (s_RRESP),
        .s_RLAST_i  (s_RLAST),  .s_RVALID_i (s_RVALID),
        
        .s_AWID_o   (s_AWID),   .s_AWADDR_o (s_AWADDR), .s_AWBURST_o(s_AWBURST),
        .s_AWLEN_o  (s_AWLEN),  .s_AWSIZE_o (s_AWSIZE), .s_AWVALID_o(s_AWVALID),
        .s_WDATA_o  (s_WDATA),  .s_WLAST_o  (s_WLAST),  .s_WVALID_o (s_WVALID),
        .s_BREADY_o (s_BREADY),
        .s_ARID_o   (s_ARID),   .s_ARADDR_o (s_ARADDR), .s_ARBURST_o(s_ARBURST),
        .s_ARLEN_o  (s_ARLEN),  .s_ARSIZE_o (s_ARSIZE), .s_ARVALID_o(s_ARVALID),
        .s_RREADY_o (s_RREADY)
    );

    // =========================================================================
    // 8. TASKS FOR TESTBENCH (ANSI C style task arguments for Verilog-2001)
    // =========================================================================

    // busrt type
    localparam AxBURST_FIXED = 2'b00;
    localparam AxBURST_INCR = 2'b01;
    localparam AxBURST_WARP = 2'b10;

    // burst len
    localparam AxSIZE_1 = 3'b000;
    localparam AxSIZE_2 = 3'b001;
    localparam AxSIZE_4 = 3'b010;
    localparam AxSIZE_8 = 3'b011;
    localparam AxSIZE_16 = 3'b100;
    localparam AxSIZE_32 = 3'b101;
    localparam AxSIZE_64 = 3'b110;
    localparam AxSIZE_128 = 3'b111;

    task master_write(
        input integer   m_idx, 
        input [31:0]    addr, 
        input [4:0]     mem_addr_ptr, 
        input [7:0]     len,
        input [1:0]     burst_type,
        input [2:0]     burst_size
    );
        begin
            @(negedge ACLK);
            $display("[TB] Ask Master[%0d] to write %0d words at address 0x%0h at %0d", m_idx, len+1, addr, $time);
            mst_set_AWADDR_i[m_idx]      <= addr;
            mst_w_set_addr_memory[m_idx] <= mem_addr_ptr;
            mst_set_AWLEN_i[m_idx]       <= len;
            mst_set_AWBURST_i[m_idx]     <= burst_type;
            mst_set_AWSIZE_i[m_idx]      <= burst_size; 
            mst_WriteTrans_EN_i[m_idx]   <= 1;
            
            @(posedge ACLK);
            mst_WriteTrans_EN_i[m_idx]   <= 0;
        end
    endtask

    task master_read(
        input integer   m_idx, 
        input [31:0]    addr, 
        input [4:0]     mem_addr_ptr, 
        input [7:0]     len,
        input [1:0]     busrt_type,
        input [2:0]     busrt_size
    );
        begin
            @(negedge ACLK);
            $display("[TB] Ask Master[%0d] to read %0d words at address 0x%0h at %0d", m_idx, len+1, addr, $time);
            mst_set_ARADDR_i[m_idx]      <= addr;
            mst_r_set_addr_memory[m_idx] <= mem_addr_ptr;
            mst_set_ARLEN_i[m_idx]       <= len;
            mst_set_ARBURST_i[m_idx]     <= busrt_type; 
            mst_set_ARSIZE_i[m_idx]      <= busrt_size; 
            mst_ReadTrans_EN_i[m_idx]    <= 1;
            
            @(posedge ACLK);
            mst_ReadTrans_EN_i[m_idx]    <= 0;
        end
    endtask

    task fill_master_ram(
        input integer m_idx, 
        input [4:0]   addr, 
        input [31:0]  data
    );
        begin
            @(negedge ACLK);
            $display("[TB] Setup Master RAM: Write 0x%h, Master[%0d], Address: 0x%0h, Time: %0d", data, m_idx, addr, $time);
            mst_address_memory[m_idx] <= addr;
            mst_DATA_MEMORY_i[m_idx]  <= data;
            mst_WRITE_EN[m_idx]       <= 1;
            @(posedge ACLK);
            mst_WRITE_EN[m_idx]       <= 0;
        end
    endtask

    task read_master_ram ( 
        input integer m_idx, 
        input [4:0]   addr
    );
        reg [31:0] data;
        begin
            @(negedge ACLK);
            mst_address_memory[m_idx] <= addr;
            mst_READ_EN[m_idx]       <= 1;
            @(posedge ACLK);
            mst_READ_EN[m_idx]       <= 0;
            data = mst_DATA_MEMORY_o[m_idx];
            $display("[TB] Setup Master RAM: Read 0x%0h, Master[%0d], Address: 0x%0h, Time: %0d", data, m_idx, addr, $time);
        end
    endtask

    task fill_slave_ram(
        input integer s_idx,      // Chỉ số của Slave (0, 1, 2...)
        input [5:0]   addr,       // Địa chỉ trong RAM nội (tối đa 64 ô nhớ theo khai báo [5:0])
        input [31:0]  data        // Dữ liệu cần ghi
    );
        begin
            @(negedge ACLK);
            $display("[TB] Setup Slave RAM: Write 0x%h, Slave[%0d], Address: 0x%0h, Time %0d", data, s_idx, addr, $time);
            slv_address_memory[s_idx] <= addr;
            slv_DATA_MEMORY_i[s_idx]  <= data;
            slv_WRITE_EN[s_idx]       <= 1;
            
            @(posedge ACLK);
            slv_WRITE_EN[s_idx]       <= 0;
        end
    endtask

    // =========================================================================
    // 9. MONITORS 
    // =========================================================================
    integer mon_i;
    integer w_size;
    integer r_size;
    reg [64-1:0] w_burst;
    reg [64-1:0] r_burst;
    always @(posedge ACLK) begin
        // master
        for (mon_i = 0; mon_i < MST_AMT; mon_i = mon_i + 1) begin
            // truyen dia chi ghi
            case (m_AWBURST[TRANS_BURST_W*(mon_i+1)-1 -: TRANS_BURST_W])
                2'b00: w_burst = "FIXED";
                2'b01: w_burst = "INCR";
                2'b10: w_burst = "WARP";
                default: w_burst = "Reserved";
            endcase

            case (m_AWSIZE[TRANS_DATA_SIZE_W*(mon_i+1)-1 -: TRANS_DATA_SIZE_W])
                3'b000: w_size = 1;
                3'b001: w_size = 2;
                3'b010: w_size = 4;
                3'b011: w_size = 8;
                3'b100: w_size = 16;
                3'b101: w_size = 32;
                3'b110: w_size = 64;
                3'b111: w_size = 128;
                default: w_size = 0;
            endcase

            if (m_AWVALID[mon_i] && m_AWREADY[mon_i]) begin
                $display("[MONITOR] Master[%0d] AW: Addr=0x%0h, Len=%0d, Size=%0d, Burst=%0s, ID=0x%0h, Time=%0d", 
                        mon_i, 
                        m_AWADDR[ADDR_WIDTH*(mon_i+1)-1 -: ADDR_WIDTH],
                        m_AWLEN[TRANS_DATA_LEN_W*(mon_i+1)-1 -: TRANS_DATA_LEN_W]+1,
                        w_size,
                        w_burst,
                        m_AWID[TRANS_MST_ID_W*(mon_i+1)-1 -: TRANS_MST_ID_W], 
                        $time);
            end
            
            // truyen dia chi nhan

            case (m_ARBURST[TRANS_BURST_W*(mon_i+1)-1 -: TRANS_BURST_W])
                2'b00: r_burst = "FIXED";
                2'b01: r_burst = "INCR";
                2'b10: r_burst = "WARP";
                default: r_burst = "Reserved";
            endcase

            case (m_ARSIZE[TRANS_DATA_SIZE_W*(mon_i+1)-1 -: TRANS_DATA_SIZE_W])
                3'b000: r_size = 1;
                3'b001: r_size = 2;
                3'b010: r_size = 4;
                3'b011: r_size = 8;
                3'b100: r_size = 16;
                3'b101: r_size = 32;
                3'b110: r_size = 64;
                3'b111: r_size = 128;
                default: r_size = 0;
            endcase

            if (m_ARVALID[mon_i] && m_ARREADY[mon_i]) begin
                $display("[MONITOR] Master[%0d] AR: Addr=0x%0h, Len=%0d, Size=%0d, Burst=%0s ID=0x%0h, Time=%0d", 
                        mon_i, 
                        m_ARADDR[ADDR_WIDTH*(mon_i+1)-1 -: ADDR_WIDTH], 
                        m_ARLEN[TRANS_DATA_LEN_W*(mon_i+1)-1 -: TRANS_DATA_LEN_W]+1,
                        r_size,
                        r_burst,
                        m_ARID[TRANS_MST_ID_W*(mon_i+1)-1 -: TRANS_MST_ID_W],
                        $time);
            end

            // nhan du lieu
            if (m_RVALID[mon_i] && m_RREADY[mon_i]) begin
                $display("[MONITOR] Master[%0d] R: Data=0x%0h, Last=%0b, ID=0x%0h, Time=%0d",
                        mon_i, 
                        m_RDATA[DATA_WIDTH*(mon_i+1)-1 -: DATA_WIDTH], 
                        m_RLAST[mon_i],
                        m_RID[TRANS_MST_ID_W*(mon_i+1)-1 -: TRANS_MST_ID_W], 
                        $time);
            end

            // truyen du lieu
            if (m_WVALID[mon_i] && m_WREADY[mon_i]) begin
                $display("[MONITOR] Master[%0d] W: Data=0x%0h, Last=%0b, Time=%0d",
                        mon_i, 
                        m_WDATA[DATA_WIDTH*(mon_i+1)-1 -: DATA_WIDTH], 
                        m_WLAST[mon_i], 
                        $time);
            end

            // phan hoi
            if (m_BVALID[mon_i] && m_BVALID[mon_i]) begin
                $display("[MONITOR] Master[%0d] B: ID=0x%0h Time=%0d",
                        mon_i,
                        m_BID[TRANS_MST_ID_W*(mon_i+1)-1 -: TRANS_MST_ID_W],
                        $time);
            end
        end

        // slave
        for (mon_i = 0; mon_i < SLV_AMT; mon_i = mon_i + 1) begin
            // AW
            case (s_AWBURST[TRANS_BURST_W*(mon_i+1)-1 -: TRANS_BURST_W])
                2'b00: w_burst = "FIXED";
                2'b01: w_burst = "INCR";
                2'b10: w_burst = "WARP";
                default: w_burst = "Reserved";
            endcase

            case (s_AWSIZE[TRANS_DATA_SIZE_W*(mon_i+1)-1 -: TRANS_DATA_SIZE_W])
                3'b000: w_size = 1;
                3'b001: w_size = 2;
                3'b010: w_size = 4;
                3'b011: w_size = 8;
                3'b100: w_size = 16;
                3'b101: w_size = 32;
                3'b110: w_size = 64;
                3'b111: w_size = 128;
                default: w_size = 0;
            endcase

            if (s_AWVALID[mon_i] && s_AWREADY[mon_i]) begin
                $display("[MONITOR] Slave[%0d] AW: Addr=0x%0h, Len=%0d, Size=%0d, Burst=%0s, ID=0x%0h, Time=%0d", 
                        mon_i, 
                        s_AWADDR[ADDR_WIDTH*(mon_i+1)-1 -: ADDR_WIDTH],
                        s_AWLEN[TRANS_DATA_LEN_W*(mon_i+1)-1 -: TRANS_DATA_LEN_W]+1,
                        w_size,
                        w_burst,
                        s_AWID[TRANS_MST_ID_W*(mon_i+1)-1 -: TRANS_MST_ID_W], 
                        $time);
            end

            // AR
            case (s_ARBURST[TRANS_BURST_W*(mon_i+1)-1 -: TRANS_BURST_W])
                2'b00: r_burst = "FIXED";
                2'b01: r_burst = "INCR";
                2'b10: r_burst = "WARP";
                default: r_burst = "Reserved";
            endcase

            case (s_ARSIZE[TRANS_DATA_SIZE_W*(mon_i+1)-1 -: TRANS_DATA_SIZE_W])
                3'b000: r_size = 1;
                3'b001: r_size = 2;
                3'b010: r_size = 4;
                3'b011: r_size = 8;
                3'b100: r_size = 16;
                3'b101: r_size = 32;
                3'b110: r_size = 64;
                3'b111: r_size = 128;
                default: r_size = 0;
            endcase

            if (s_ARVALID[mon_i] && s_ARREADY[mon_i]) begin
                $display("[MONITOR] Slave[%0d] AR: Addr=0x%0h, Len=%0d, Size=%0d, Burst=%0s ID=0x%0h, Time=%0d", 
                        mon_i, 
                        s_ARADDR[ADDR_WIDTH*(mon_i+1)-1 -: ADDR_WIDTH], 
                        s_ARLEN[TRANS_DATA_LEN_W*(mon_i+1)-1 -: TRANS_DATA_LEN_W]+1,
                        r_size,
                        r_burst,
                        s_ARID[TRANS_MST_ID_W*(mon_i+1)-1 -: TRANS_MST_ID_W],
                        $time);
            end

            // W
            if (s_WVALID[mon_i] && s_WREADY[mon_i]) begin
                $display("[MONITOR] Slave[%0d] W: Data=0x%0h, Last=%0b, Time=%0d",
                        mon_i, 
                        s_WDATA[DATA_WIDTH*(mon_i+1)-1 -: DATA_WIDTH], 
                        s_WLAST[mon_i], 
                        $time);
            end

            // B 
            if (s_BVALID[mon_i] && s_BVALID[mon_i]) begin
                $display("[MONITOR] Slave[%0d] B: ID=0x%0h Time=%0d",
                        mon_i,
                        s_BID[TRANS_MST_ID_W*(mon_i+1)-1 -: TRANS_MST_ID_W],
                        $time);
            end

            // R
            if (s_RVALID[mon_i] && s_RREADY[mon_i]) begin
                $display("[MONITOR] Slave[%0d] R: Data=0x%0h, Last=%0b, ID=0x%0h, Time=%0d",
                        mon_i, 
                        s_RDATA[DATA_WIDTH*(mon_i+1)-1 -: DATA_WIDTH], 
                        s_RLAST[mon_i],
                        s_RID[TRANS_MST_ID_W*(mon_i+1)-1 -: TRANS_MST_ID_W], 
                        $time);
            end
        end
    end

    // =========================================================================
    // 10. MAIN TEST SCENARIO
    // =========================================================================
    initial begin
        $dumpfile("tb_axi_interconnect.vcd");
        $dumpvars(0, tb_axi_interconnect);
        wait(ARESETn == 1);
        #100;
        
        // 1. Nạp dữ liệu vào RAM nội của Master 0
        fill_master_ram(0, 5'd0, 32'hDEADBEEF);
        fill_master_ram(0, 5'd4, 32'h12345678);

        #50;
        read_master_ram(0, 0);
        read_master_ram(0, 4);

        // 2. Master 0 thực hiện ghi sang Slave (VD: Map vùng nhớ 0x8000_0000 thuộc Slave 2)
        #50;
        master_write(0, 32'h8000_0000, 5'd0, 1, AxBURST_INCR, AxSIZE_32); 
        
        // 3. Đợi một khoảng thời gian, sau đó Master 1 đọc lại
        #500;
        master_read(1, 32'h8000_0000, 5'd0, 1, AxBURST_INCR, AxSIZE_32);

        #1000;
        $finish;
    end

endmodule