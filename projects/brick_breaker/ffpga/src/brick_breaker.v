// main breakout game module
(* top *) module brick_breaker(
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) input reset,
    
    (* iopad_external_pin *) input btn_left,
    (* iopad_external_pin *) input btn_right,
    (* iopad_external_pin *) input btn_shoot,
    
    (* iopad_external_pin *) output DO,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) output do_en
);
 
    assign do_en = 1'b1;
    assign clk_en = 1'b1;

    wire [7:0] address;
    wire [7:0] red, green, blue;
    wire [3:0] px, py;

    wire left_db;
    wire right_db;
    wire shoot_db;

    // debounce input buttons
    debounce db_left  (.clk(clk), .btn_in(btn_left),  .btn_out(left_db));
    debounce db_right (.clk(clk), .btn_in(btn_right), .btn_out(right_db));
    debounce db_shoot (.clk(clk), .btn_in(btn_shoot), .btn_out(shoot_db));

    // convert address to grid
    coordinate_map mapper (
        .address(address),
        .px(px),
        .py(py)
    );

    reg [23:0] player_timer;
    reg [23:0] ball_timer;
    
    // set game speed using clock dividers
    wire tick_player = (player_timer == 24'd1_000_000); 
    wire tick_ball   = (ball_timer   == 24'd3_333_333); 
    
    // update timers
    always @(posedge clk) begin
        if (~reset) begin
            player_timer <= 0;
            ball_timer <= 0;
        end else begin
            player_timer <= tick_player ? 0 : player_timer + 1;
            ball_timer   <= tick_ball   ? 0 : ball_timer + 1;
        end
    end

    // game state variables
    reg [3:0] player_x; 
    reg [3:0] ball_x, ball_y;
    reg       ball_dir_x; 
    reg       ball_dir_y; 
    reg [14:0] bricks_alive; 
    reg        ball_active;

    // define hit boxes for each brick
    wire hit_b0  = (ball_y == 1) && (ball_x == 1 || ball_x == 2)   && bricks_alive[0];
    wire hit_b1  = (ball_y == 1) && (ball_x == 4 || ball_x == 5)   && bricks_alive[1];
    wire hit_b2  = (ball_y == 1) && (ball_x == 7 || ball_x == 8)   && bricks_alive[2];
    wire hit_b3  = (ball_y == 1) && (ball_x == 10 || ball_x == 11) && bricks_alive[3];
    wire hit_b4  = (ball_y == 1) && (ball_x == 13 || ball_x == 14) && bricks_alive[4];

    wire hit_b5  = (ball_y == 3) && (ball_x == 1 || ball_x == 2)   && bricks_alive[5];
    wire hit_b6  = (ball_y == 3) && (ball_x == 4 || ball_x == 5)   && bricks_alive[6];
    wire hit_b7  = (ball_y == 3) && (ball_x == 7 || ball_x == 8)   && bricks_alive[7];
    wire hit_b8  = (ball_y == 3) && (ball_x == 10 || ball_x == 11) && bricks_alive[8];
    wire hit_b9  = (ball_y == 3) && (ball_x == 13 || ball_x == 14) && bricks_alive[9];

    wire hit_b10 = (ball_y == 5) && (ball_x == 1 || ball_x == 2)   && bricks_alive[10];
    wire hit_b11 = (ball_y == 5) && (ball_x == 4 || ball_x == 5)   && bricks_alive[11];
    wire hit_b12 = (ball_y == 5) && (ball_x == 7 || ball_x == 8)   && bricks_alive[12];
    wire hit_b13 = (ball_y == 5) && (ball_x == 10 || ball_x == 11) && bricks_alive[13];
    wire hit_b14 = (ball_y == 5) && (ball_x == 13 || ball_x == 14) && bricks_alive[14];

    // check if any brick was hit
    wire any_brick_hit = hit_b0  || hit_b1  || hit_b2  || hit_b3  || hit_b4  || 
                         hit_b5  || hit_b6  || hit_b7  || hit_b8  || hit_b9  || 
                         hit_b10 || hit_b11 || hit_b12 || hit_b13 || hit_b14;

    // main game logic loop
    always @(posedge clk) begin
        if (~reset) begin
            player_x     <= 4'd6;
            bricks_alive <= 15'b111_111_111_111_111;
            ball_active  <= 1'b0;
            ball_x       <= 4'd7; 
            ball_y       <= 4'd14;
            ball_dir_x   <= 1'b1;         
            ball_dir_y   <= 1'b0;         
        end else begin
            
            // paddle movement logic
            if (tick_player) begin
                if (left_db && player_x > 0) 
                    player_x <= player_x - 1;
                else if (right_db && player_x < 12) 
                    player_x <= player_x + 1;
            end
            
            // lock ball to paddle before shooting
            if (!ball_active) begin
                ball_x <= player_x + 1;
                ball_y <= 4'd14;
                if (shoot_db) begin
                    ball_active <= 1'b1;
                    ball_dir_y  <= 1'b0;
                    ball_dir_x  <= 1'b1;
                end
            end else if (tick_ball) begin
                
                // calculate ball x position
                if (ball_dir_x) begin 
                    if (ball_x == 15) begin ball_dir_x <= 1'b0; ball_x <= 14; end
                    else ball_x <= ball_x + 1;
                end else begin 
                    if (ball_x == 0) begin ball_dir_x <= 1'b1; ball_x <= 1; end
                    else ball_x <= ball_x - 1;
                end

                // handle brick destruction and bouncing
                if (any_brick_hit) begin
                    if (hit_b0)  bricks_alive[0]  <= 1'b0;
                    if (hit_b1)  bricks_alive[1]  <= 1'b0;
                    if (hit_b2)  bricks_alive[2]  <= 1'b0;
                    if (hit_b3)  bricks_alive[3]  <= 1'b0;
                    if (hit_b4)  bricks_alive[4]  <= 1'b0;
                    if (hit_b5)  bricks_alive[5]  <= 1'b0;
                    if (hit_b6)  bricks_alive[6]  <= 1'b0;
                    if (hit_b7)  bricks_alive[7]  <= 1'b0;
                    if (hit_b8)  bricks_alive[8]  <= 1'b0;
                    if (hit_b9)  bricks_alive[9]  <= 1'b0;
                    if (hit_b10) bricks_alive[10] <= 1'b0;
                    if (hit_b11) bricks_alive[11] <= 1'b0;
                    if (hit_b12) bricks_alive[12] <= 1'b0;
                    if (hit_b13) bricks_alive[13] <= 1'b0;
                    if (hit_b14) bricks_alive[14] <= 1'b0;
                    
                    ball_dir_y <= ~ball_dir_y; 
                    ball_y <= ball_dir_y ? ball_y - 1 : ball_y + 1; 
                end else if (ball_dir_y) begin 
                    
                    // paddle bounce and bottom edge check
                    if (ball_y == 14 && ball_x >= player_x && ball_x <= player_x + 3) begin
                        ball_dir_y <= 1'b0; 
                        ball_y <= 13;
                    end else if (ball_y == 15) begin
                        ball_active <= 1'b0;
                    end else begin
                        ball_y <= ball_y + 1;
                    end
                end else begin 
                    
                    // top edge bounce
                    if (ball_y == 0) begin
                        ball_dir_y <= 1'b1; 
                        ball_y <= 1;
                    end else begin
                        ball_y <= ball_y - 1;
                    end
                end
            end
        end
    end

    // generate pixel colors
    game_renderer renderer (
        .px(px),
        .py(py),
        .player_x(player_x),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .bricks_alive(bricks_alive),
        .red(red),
        .green(green),
        .blue(blue)
    );

    // instantiate the led matrix driver
    ws2811 #(
        .NUM_LEDS(256),
        .SYSTEM_CLOCK(50_000_000)
    ) driver (
        .clk(clk),
        .reset(~reset),
        
        .address(address),
        .red_in(green),    
        .green_in(red),    
        .blue_in(blue),
        
        .DO(DO)
    );
   
endmodule
