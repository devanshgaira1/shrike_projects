module coordinate_map (
    input [7:0] address,
    output [3:0] px,
    output [3:0] py
);
    assign px = (address < 64)  ? address[2:0] :           
                (address < 128) ? address[2:0] + 4'd8 :    
                (address < 192) ? address[2:0] :           
                                  address[2:0] + 4'd8;     
                                  
    assign py = (address < 64)  ? address[5:3] :           
                (address < 128) ? address[5:3] :           
                (address < 192) ? address[5:3] + 4'd8 :    
                                  address[5:3] + 4'd8;     
endmodule
