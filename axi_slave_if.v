module axi_slave_if #(
    parameter ID_WIDTH   = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter RAM_SIZE = 128,

    localparam RAM_ADDR_WIDTH = $clog2(RAM_SIZE)
)(
    input                       ACLK_i,
    input                       ARESETn_i,

    //================ LOCAL CONTROL INTERFACE =================//
    input  [RAM_ADDR_WIDTH-1:0]                s_address_memory,
    input                       s_READ_EN,
    input  [DATA_WIDTH-1:0]                s_DATA_MEMORY_i, 
    input                       s_WRITE_EN,
    output [DATA_WIDTH-1:0]                s_DATA_MEMORY_o, 
    
    //================ WRITE ADDRESS CHANNEL ===================//
    input                       s_AWVALID_i,
    input  [ID_WIDTH-1:0]       s_AWID_i,
    input  [ADDR_WIDTH-1:0]     s_AWADDR_i,
    input  [7:0]                s_AWLEN_i,
    input  [1:0]                s_AWBURST_i,
    input  [2:0]                s_AWSIZE_i,
    output                      s_AWREADY_o,

    //================ WRITE DATA CHANNEL ======================//
    input                       s_WVALID_i,
    input  [DATA_WIDTH-1:0]     s_WDATA_i,
    input  [DATA_WIDTH/8-1:0]   s_WSTRB_i,   // Đã bổ sung Strobe
    input                       s_WLAST_i,
    output                      s_WREADY_o,

    //================ WRITE RESPONSE CHANNEL ==================//
    output                      s_BVALID_o,
    output [ID_WIDTH-1:0]       s_BID_o,
    output [1:0]                s_BRESP_o,
    input                       s_BREADY_i,

    //================ READ ADDRESS CHANNEL ====================//
    input                       s_ARVALID_i,
    input  [ID_WIDTH-1:0]       s_ARID_i,
    input  [ADDR_WIDTH-1:0]     s_ARADDR_i,
    input  [7:0]                s_ARLEN_i,
    input  [1:0]                s_ARBURST_i,
    input  [2:0]                s_ARSIZE_i,    
    output                      s_ARREADY_o,

    //================ READ DATA CHANNEL =======================//
    output                      s_RVALID_o,
    output                      s_RLAST_o,
    output [ID_WIDTH-1:0]       s_RID_o,
    output [DATA_WIDTH-1:0]     s_RDATA_o,
    output [1:0]                s_RRESP_o,
    input                       s_RREADY_i
);

    //================ INTERNAL WIRES =================//
    wire r_ram_access, r_req, r_busy;
    wire w_ram_access, w_req, w_busy;
    wire [1:0] ram_mux_sel;

    wire [RAM_ADDR_WIDTH-1:0]   ctrl_ram_addr, w_ram_addr, r_ram_addr, mux_ram_addr;
    wire [DATA_WIDTH-1:0]   ctrl_ram_din,  w_ram_din,  r_ram_din,  mux_ram_din;
    wire                    ctrl_ram_we,   w_ram_we,   r_ram_we,   mux_ram_we;
    wire [DATA_WIDTH/8-1:0] ctrl_strobe = {(DATA_WIDTH/8){1'b1}};
    wire [DATA_WIDTH/8-1:0] w_strobe, r_strobe, mux_strobe;
    
    wire [DATA_WIDTH-1:0]   ram_dout;

    //================ INSTANTIATIONS =================//

    // 1. Slave Control
    axi_slave_control #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_slave_ctrl (
        .ACLK_i(ACLK_i), .ARESETn_i(ARESETn_i),
        .s_address_memory(s_address_memory),
        .s_READ_EN(s_READ_EN),
        .s_DATA_MEMORY_i(s_DATA_MEMORY_i),
        .s_WRITE_EN(s_WRITE_EN),
        .s_DATA_MEMORY_o(s_DATA_MEMORY_o),
        .ctrl_ram_address(ctrl_ram_addr),
        .ctrl_ram_data_in(ctrl_ram_din),
        .ctrl_ram_wren(ctrl_ram_we),
        .ram_data_out(ram_dout),
        .ram_mux_sel(ram_mux_sel),
        .r_ram_access(r_ram_access), .r_req(r_req), .r_busy(r_busy),
        .w_ram_access(w_ram_access), .w_req(w_req), .w_busy(w_busy)
    );

    // 2. Slave Write FSM
    axi_slave_w #(
        .ID_WIDTH(ID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) u_slave_w (
        .ACLK_i(ACLK_i), .ARESETn_i(ARESETn_i),
        .w_ram_access(w_ram_access), .w_req(w_req), .w_busy(w_busy),
        .ram_address(w_ram_addr), .ram_data_in(w_ram_din), .ram_wren(w_ram_we), .ram_strobe(w_strobe), .ram_data_out(ram_dout),
        .s_AWVALID_i(s_AWVALID_i), .s_AWID_i(s_AWID_i), .s_AWADDR_i(s_AWADDR_i), .s_AWLEN_i(s_AWLEN_i), .s_AWBURST_i(s_AWBURST_i), .s_AWSIZE_i(s_AWSIZE_i), .s_AWREADY_o(s_AWREADY_o),
        .s_WVALID_i(s_WVALID_i), .s_WDATA_i(s_WDATA_i), .s_WSTRB_i(s_WSTRB_i), .s_WLAST_i(s_WLAST_i), .s_WREADY_o(s_WREADY_o),
        .s_BVALID_o(s_BVALID_o), .s_BID_o(s_BID_o), .s_BRESP_o(s_BRESP_o), .s_BREADY_i(s_BREADY_i)
    );

    // 3. Slave Read FSM
    axi_slave_r #(
        .ID_WIDTH(ID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) u_slave_r (
        .ACLK_i(ACLK_i), .ARESETn_i(ARESETn_i),
        .r_ram_access(r_ram_access), .r_req(r_req), .r_busy(r_busy),
        .ram_address(r_ram_addr), .ram_data_in(r_ram_din), .ram_wren(r_ram_we), .ram_strobe(r_strobe), .ram_data_out(ram_dout),
        .s_ARVALID_i(s_ARVALID_i), .s_ARID_i(s_ARID_i), .s_ARADDR_i(s_ARADDR_i), .s_ARLEN_i(s_ARLEN_i), .s_ARBURST_i(s_ARBURST_i), .s_ARSIZE_i(s_ARSIZE_i), .s_ARREADY_o(s_ARREADY_o),
        .s_RVALID_o(s_RVALID_o), .s_RLAST_o(s_RLAST_o), .s_RID_o(s_RID_o), .s_RDATA_o(s_RDATA_o), .s_RRESP_o(s_RRESP_o), .s_RREADY_i(s_RREADY_i)
    );

    // 4. RAM MUX
    axi_ram_mux #(
        .DATA_WIDTH(DATA_WIDTH), .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) u_ram_mux (
        .ram_mux_sel(ram_mux_sel),
        .ctrl_ram_address(ctrl_ram_addr), .ctrl_ram_data_in(ctrl_ram_din), .ctrl_ram_wren(ctrl_ram_we), .ctrl_ram_strobe(ctrl_strobe),
        .w_ram_address(w_ram_addr), .w_ram_data_in(w_ram_din), .w_ram_wren(w_ram_we), .w_strobe(w_strobe),
        .r_ram_address(r_ram_addr), .r_ram_data_in(r_ram_din), .r_ram_wren(r_ram_we), .r_strobe(r_strobe),
        .ram_addr_o(mux_ram_addr), .ram_data_i_o(mux_ram_din), .ram_wren_o(mux_ram_we), .ram_strobe_o(mux_strobe)
    );

    // 5. AXI RAM
    axi_ram #(
        .ID_WIDTH(ID_WIDTH), .DATA_WIDTH(DATA_WIDTH), .RAM_SIZE(128)
    ) u_axi_ram (
        .ACLK_i(ACLK_i),
        .ram_wren(mux_ram_we),
        .ram_address(mux_ram_addr),
        .ram_data_in(mux_ram_din),
        .ram_data_out(ram_dout),
        .strobe(mux_strobe)
    );

endmodule