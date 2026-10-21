// graphics rendering logic for all game objects
module game_renderer (
    input [3:0] px,
    input [3:0] py,
    input [3:0] player_x,
    input [3:0] ball_x,
    input [3:0] ball_y,
    input [14:0] bricks_alive,
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);
    wire is_paddle = (py == 15) && (px >= player_x && px <= player_x + 3);

    wire draw_r1 = (py == 1) && (
        ((px == 1 || px == 2)   && bricks_alive[0]) ||
        ((px == 4 || px == 5)   && bricks_alive[1]) ||
        ((px == 7 || px == 8)   && bricks_alive[2]) ||
        ((px == 10 || px == 11) && bricks_alive[3]) ||
        ((px == 13 || px == 14) && bricks_alive[4])
    );

    wire draw_r2 = (py == 3) && (
        ((px == 1 || px == 2)   && bricks_alive[5]) ||
        ((px == 4 || px == 5)   && bricks_alive[6]) ||
        ((px == 7 || px == 8)   && bricks_alive[7]) ||
        ((px == 10 || px == 11) && bricks_alive[8]) ||
        ((px == 13 || px == 14) && bricks_alive[9])
    );

    wire draw_r3 = (py == 5) && (
        ((px == 1 || px == 2)   && bricks_alive[10]) ||
        ((px == 4 || px == 5)   && bricks_alive[11]) ||
        ((px == 7 || px == 8)   && bricks_alive[12]) ||
        ((px == 10 || px == 11) && bricks_alive[13]) ||
        ((px == 13 || px == 14) && bricks_alive[14])
    );

    // assign colors based on pixel location
    always @(*) begin
        if (draw_r1) begin
            red = 8'd255; green = 8'd0; blue = 8'd0; 
        end
        else if (draw_r2) begin
            red = 8'd255; green = 8'd255; blue = 8'd0; 
        end
        else if (draw_r3) begin
            red = 8'd0; green = 8'd255; blue = 8'd0; 
        end
        else if (is_paddle) begin
            red = 8'd0; green = 8'd255; blue = 8'd255; 
        end
        else if (py == ball_y && px == ball_x) begin
            red = 8'd255; green = 8'd255; blue = 8'd255; 
        end
        else begin
            red = 8'd0; green = 8'd0; blue = 8'd0; 
        end
    end
endmodule