module axi_master_if #(
    parameter ID_WIDTH = 4,
    parameter ADDR_WIDTH = 32,    // Tối đa tùy vào số lượng device và memory
    parameter DATA_WIDTH = 32,     // Tối đa 1024
    parameter RAM_SIZE = 128, 

    localparam RAM_ADDR_WIDTH = $clog2(RAM_SIZE)
)(
    input                       ACLK_i,
    input                       ARESETn_i,

    //================ Control ======================//
    // Tín hiệu đọc và ghi vào RAM nội
    input  [RAM_ADDR_WIDTH-1:0] m_address_memory,
    input                       m_READ_EN,
    input  [DATA_WIDTH-1:0]     m_DATA_MEMORY_i, 
    input                       m_WRITE_EN,
    output [DATA_WIDTH-1:0]     m_DATA_MEMORY_o, 
    
    // Transaction READ
    input                       ReadTrans_EN_i,
    input  [RAM_ADDR_WIDTH-1:0] r_set_addr_memory,   
    input  [ADDR_WIDTH-1:0]     set_ARADDR_i,
    input  [1:0]                set_ARBURST_i,
    input  [7:0]                set_ARLEN_i,
    input  [2:0]                set_ARSIZE_i,
    
    // Transaction WRITE	
    input                       WriteTrans_EN_i,	
    input  [RAM_ADDR_WIDTH-1:0] w_set_addr_memory,  
    input  [ADDR_WIDTH-1:0]     set_AWADDR_i,
    input  [1:0]                set_AWBURST_i,
    input  [7:0]                set_AWLEN_i,
    input  [2:0]                set_AWSIZE_i,
	   
    //================ WRITE ADDRESS =================//
    output                      m_AWVALID_o,
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

    //=========================================================
    // KHAI BÁO CÁC DÂY NỐI NỘI BỘ (INTERNAL WIRES)
    //=========================================================
    
    // Dây tín hiệu Access/Request/Busy giữa Control và Master R/W
    wire r_ram_access, r_req, r_busy;
    wire w_ram_access, w_req, w_busy;

    // Dây tín hiệu điều khiển MUX từ Control
    wire [1:0] ram_mux_sel;

    // Dây tín hiệu từ Control -> MUX
    wire [RAM_ADDR_WIDTH-1:0]   ctrl_ram_address;
    wire [DATA_WIDTH-1:0]       ctrl_ram_data_in;
    wire                        ctrl_ram_wren;
    wire [DATA_WIDTH/8-1:0]     ctrl_ram_strobe = {(DATA_WIDTH/8){1'b1}}; // Cho phép ghi tất cả các byte [cite: 134, 259]

    // Dây tín hiệu từ Master Write -> MUX
    wire [RAM_ADDR_WIDTH-1:0]   w_ram_address;
    wire [DATA_WIDTH-1:0]       w_ram_data_in;
    wire                        w_ram_wren;
    wire [DATA_WIDTH/8-1:0]     w_strobe;

    // Dây tín hiệu từ Master Read -> MUX
    wire [RAM_ADDR_WIDTH-1:0]   r_ram_address;
    wire [DATA_WIDTH-1:0]       r_ram_data_in;
    wire                        r_ram_wren;
    wire [DATA_WIDTH/8-1:0]     r_strobe;

    // Dây tín hiệu ngõ ra từ MUX -> RAM
    wire [RAM_ADDR_WIDTH-1:0]   mux_ram_addr;
    wire [DATA_WIDTH-1:0]       mux_ram_data_in;
    wire                        mux_ram_wren;
    wire [DATA_WIDTH/8-1:0]     mux_ram_strobe;

    // Dây tín hiệu từ RAM dội ngược ra (Broadcast cho Control, W, R)
    wire [DATA_WIDTH-1:0]       ram_data_out;


    //=========================================================
    // KHỞI TẠO CÁC MODULE CON (INSTANTIATIONS)
    //=========================================================

    // 1. Khối phân xử Control [cite: 239]
    axi_master_control #(
        .ID_WIDTH(ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) u_control (
        .ACLK_i(ACLK_i),
        .ARESETn_i(ARESETn_i),
        
        .m_address_memory(m_address_memory),
        .m_READ_EN(m_READ_EN),
        .m_DATA_MEMORY_i(m_DATA_MEMORY_i), 
        .m_WRITE_EN(m_WRITE_EN),
        .m_DATA_MEMORY_o(m_DATA_MEMORY_o),
        
        .ctrl_ram_address(ctrl_ram_address),
        .ctrl_ram_data_in(ctrl_ram_data_in),
        .ctrl_ram_wren(ctrl_ram_wren),
        .ram_data_out(ram_data_out),
        .ram_mux_sel(ram_mux_sel),
        
        .r_ram_access(r_ram_access),
        .r_req(r_req),
        .r_busy(r_busy),
        
        .w_ram_access(w_ram_access),
        .w_req(w_req),
        .w_busy(w_busy)
    );

    // 2. Khối AXI Write Master [cite: 154]
    axi_master_w #(
        .ID_WIDTH(ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) u_master_w (
        .ACLK_i(ACLK_i),
        .ARESETn_i(ARESETn_i),
        
        .w_ram_access(w_ram_access),
        .w_req(w_req),
        .w_busy(w_busy),
        
        .WriteTrans_EN_i(WriteTrans_EN_i),	
        .w_set_addr_memory(w_set_addr_memory),  
        .set_AWADDR_i(set_AWADDR_i),
        .set_AWBURST_i(set_AWBURST_i),
        .set_AWLEN_i(set_AWLEN_i),
        .set_AWSIZE_i(set_AWSIZE_i),
        
        .ram_address(w_ram_address),
        .ram_data_in(w_ram_data_in),
        .ram_wren(w_ram_wren),
        .ram_data_out(ram_data_out),
        .ram_strobe(w_strobe),
        
        .m_AWVALID_o(m_AWVALID_o),
        .m_AWID_o(m_AWID_o),
        .m_AWADDR_o(m_AWADDR_o),
        .m_AWBURST_o(m_AWBURST_o),
        .m_AWLEN_o(m_AWLEN_o),
        .m_AWSIZE_o(m_AWSIZE_o),
        .m_AWREADY_i(m_AWREADY_i),
        
        .m_WVALID_o(m_WVALID_o),
        .m_WDATA_o(m_WDATA_o),
        .m_WLAST_o(m_WLAST_o),
        .m_WREADY_i(m_WREADY_i),
        
        .m_BVALID_i(m_BVALID_i),
        .m_BID_i(m_BID_i),
        .m_BRESP_i(m_BRESP_i),
        .m_BREADY_o(m_BREADY_o)
    );

    // 3. Khối AXI Read Master [cite: 191]
    axi_master_r #(
        .ID_WIDTH(ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) u_master_r (
        .ACLK_i(ACLK_i),
        .ARESETn_i(ARESETn_i),
        
        .r_ram_access(r_ram_access),
        .r_req(r_req),
        .r_busy(r_busy),
        
        .ReadTrans_EN_i(ReadTrans_EN_i),
        .r_set_addr_memory(r_set_addr_memory),   
        .set_ARADDR_i(set_ARADDR_i),
        .set_ARBURST_i(set_ARBURST_i),
        .set_ARLEN_i(set_ARLEN_i),
        .set_ARSIZE_i(set_ARSIZE_i),
        
        .ram_address(r_ram_address),
        .ram_data_in(r_ram_data_in),
        .ram_wren(r_ram_wren),
        .ram_data_out(ram_data_out),
        .ram_strobe(r_strobe),
        
        .m_ARVALID_o(m_ARVALID_o),
        .m_ARID_o(m_ARID_o),
        .m_ARADDR_o(m_ARADDR_o),
        .m_ARBURST_o(m_ARBURST_o),
        .m_ARLEN_o(m_ARLEN_o),
        .m_ARSIZE_o(m_ARSIZE_o),
        .m_ARREADY_i(m_ARREADY_i),
        
        .m_RVALID_i(m_RVALID_i),
        .m_RLAST_i(m_RLAST_i),
        .m_RID_i(m_RID_i),
        .m_RDATA_i(m_RDATA_i),
        .m_RRESP_i(m_RRESP_i),
        .m_RREADY_o(m_RREADY_o)
    );

    // 4. Khối Multiplexer (MUX) cho RAM [cite: 133]
    axi_ram_mux #(
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) u_ram_mux (
        .ram_mux_sel(ram_mux_sel),
        
        // Từ Control
        .ctrl_ram_address(ctrl_ram_address),
        .ctrl_ram_data_in(ctrl_ram_data_in),
        .ctrl_ram_wren(ctrl_ram_wren),
        .ctrl_ram_strobe(ctrl_ram_strobe),
        
        // Từ Master W
        .w_ram_address(w_ram_address),
        .w_ram_data_in(w_ram_data_in),
        .w_ram_wren(w_ram_wren),
        .w_strobe(w_strobe),
        
        // Từ Master R
        .r_ram_address(r_ram_address),
        .r_ram_data_in(r_ram_data_in),
        .r_ram_wren(r_ram_wren),
        .r_strobe(r_strobe),
        
        // Output ra RAM
        .ram_addr_o(mux_ram_addr),
        .ram_data_i_o(mux_ram_data_in),
        .ram_wren_o(mux_ram_wren),
        .ram_strobe_o(mux_ram_strobe)
    );

    // 5. Khối Block RAM (128 words) [cite: 147]
    axi_ram #(
        .ID_WIDTH(ID_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_SIZE(RAM_SIZE)
    ) u_axi_ram (
        .ACLK_i(ACLK_i),
        .ram_wren(mux_ram_wren),
        .ram_address(mux_ram_addr),
        .ram_data_in(mux_ram_data_in),
        .ram_data_out(ram_data_out),
        .strobe(mux_ram_strobe)
    );

endmodule