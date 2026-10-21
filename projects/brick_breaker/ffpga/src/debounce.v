// simple button debounce logic
module debounce (
    input clk,
    input btn_in,
    output reg btn_out
);
    reg [15:0] count;
    reg sync_0, sync_1;
    
    always @(posedge clk) begin
        sync_0 <= btn_in;
        sync_1 <= sync_0;
    end
    
    always @(posedge clk) begin
        if (sync_1 == btn_out) begin
            count <= 0;
        end else begin
            count <= count + 1;
            if (count == 16'hFFFF) begin
                btn_out <= sync_1;
                count <= 0;
            end
        end
    end
endmodule

