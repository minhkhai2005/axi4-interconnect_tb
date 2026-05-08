module axi_ram #(
    parameter ID_WIDTH   = 4,
    parameter DATA_WIDTH = 32,
    parameter RAM_SIZE   = 128, // Tổng số byte trong RAM

    // Số lượng byte lane (ví dụ: 32-bit data bus = 4 lanes)
    localparam STRB_WIDTH = DATA_WIDTH / 8,
    parameter ADDR_WIDTH = $clog2(RAM_SIZE)
)(
    input                           ACLK_i,

    input                           ram_wren,    // 1: Write, 0: Read
    input      [ADDR_WIDTH-1:0]     ram_address, // Địa chỉ byte
    input      [DATA_WIDTH-1:0]     ram_data_in,
    output reg [DATA_WIDTH-1:0]     ram_data_out,
    input      [STRB_WIDTH-1:0]     strobe       // Tín hiệu byte-lane enable
);

    // =========================================================
    // RAM declaration
    // Mảng bộ nhớ 8-bit (byte), tổng quy mô RAM_SIZE bytes
    // =========================================================
    reg [7:0] mem [0:RAM_SIZE-1];

    integer i;

    // =========================================================
    // WRITE + READ LOGIC
    // =========================================================
    always @(posedge ACLK_i) begin
        // Mặc định giá trị đọc (tránh giữ giá trị cũ nếu không cần thiết)
        // Hoặc bạn có thể giữ nguyên để tối ưu công suất
        
        if (ram_wren) begin
            // ================= WRITE =================
            // Duyệt qua từng byte lane dựa trên DATA_WIDTH
            for (i = 0; i < STRB_WIDTH; i = i + 1) begin
                // Kiểm tra xem địa chỉ có nằm trong vùng nhớ hợp lệ không
                if (strobe[i] && (ram_address + i < RAM_SIZE)) begin
                    mem[ram_address + i] <= ram_data_in[i*8 +: 8];
                end
            end
        end 
    end

    always @(*) begin
        // ================= READ =================
        // Đọc đồng thời các byte liên tiếp từ địa chỉ cơ sở để lấp đầy bus
        for (i = 0; i < STRB_WIDTH; i = i + 1) begin
            if (ram_address + i < RAM_SIZE) begin
                ram_data_out[i*8 +: 8] <= mem[ram_address + i];
            end else begin
                ram_data_out[i*8 +: 8] <= 8'h00; // Trả về 0 nếu vượt quá RAM_SIZE
            end
        end
    end


endmodule