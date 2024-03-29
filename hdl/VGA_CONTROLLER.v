module VGA_CONTROLLER (
//250 pixels/second
//pixel clock
input i_CLK,
input i_RESET_n,
//RRRGGGGBB based on user manual
input [7:0] i_RGB,

//starts at low even though high is default for many states in state machine
output reg o_HSYNC = 1'b0,
output reg o_VSYNC = 1'b0,
output reg [3:0] o_RED,
output reg [3:0] o_GREEN,
output reg [3:0] o_BLUE
);

//800 pixles x 640 lines
//takes in 8 bit of data and
//horizontal states
reg [3:0] r_H_STATE = 3'b000;
parameter s_H_ACTIVE = 3'b000;
parameter s_H_FRONT = 3'b001;
parameter s_H_SYNC = 3'b010;
parameter s_H_BACK = 3'b011;

//horizontal cycles - 800 pixels for one whole line
parameter c_H_ACTIVE_CYCLES = 640 ;
parameter c_H_FRONT_CYCLES = 16;
parameter c_H_SYNC_CYCLES = 96;
parameter c_H_BACK_CYCLES = 48;

//horizontal registers and variables
reg [15:0] r_H_COUNTER = 0;
reg [15:0] r_V_COUNTER = 0;




//RGB regs
//reg [3:0] r_Red = 4'b0;
//reg [3:0] r_Green = 4'b0
//reg [3:0] r_Blue = 4'b0;


//vertical states
reg [3:0] r_V_STATE = 3'b100;
parameter s_V_ACTIVE = 3'b100;
parameter s_V_FRONT = 3'b101;
parameter s_V_SYNC = 3'b110;
parameter s_V_BACK = 3'b111;

//vertical cycles/lines - 525 lines for the whole frame
parameter c_V_ACTIVE_CYCLES = 480;
parameter c_V_FRONT_CYCLES = 33;
parameter c_V_SYNC_CYCLES = 2;
parameter c_V_BACK_CYCLES = 10; 

parameter c_HIGH = 1'b1;
parameter c_LOW = 1'b0;

//end of line to indicate end of a pixel line
reg r_END_LINE = 1'b0;	

//assign statements for registers does not seem right
//assign o_HSYNC = r_HSYNC_SIG;
//assign o_VSYNC = r_VSYNC_SIG;



always @ (posedge i_CLK or negedge i_RESET_n) 
	if (~i_RESET_n) begin
	//go back to active state, at the first pixel of the frame
	r_H_STATE <= s_H_ACTIVE;
	r_V_STATE <= s_V_ACTIVE;
	r_H_COUNTER <= 0;
	r_V_COUNTER <= 0;
	r_END_LINE <= 0;
	o_Red <= 4'b0;
	o_Green <= 4'b0;
	o_Blue <= 4'b0;
	
	
	else
	begin
	
		//finishes drawing one line then move to the next line
		//hence horizontal state first before vertical
		case (r_H_STATE) 
		s_H_ACTIVE: 
			begin
				o_HSYNC_SIG <= c_HIGH;
			
				//not end of line yet
				r_END_LINE <= c_LOW;
		
				// 640 cycles
				if (r_H_COUNTER < c_H_ACTIVE_CYCLES) begin
					r_H_COUNTER <= r_H_COUNTER + 1;
					r_H_STATE <= s_H_ACTIVE;
				end else begin
					r_H_COUNTER <= 0;
					r_H_STATE <= s_H_FRONT;
				end
			end
		s_H_FRONT:
			begin
				o_HSYNC_SIG <= c_HIGH;
		
				//not end of line yet
				r_END_LINE <= c_LOW;
		
				// 16 cycles
				if (r_H_COUNTER < c_H_FRONT_CYCLES) begin
					r_H_COUNTER <= r_H_COUNTER + 1;
					r_H_STATE <= s_H_FRONT;
				end else begin
					r_H_COUNTER <= 0;
					r_H_STATE <= s_H_SYNC;
				end
			end
		s_H_SYNC:
			begin
				//sync pulse requires hsync signal to be driven low
				o_HSYNC_SIG <= c_LOW;
				
				r_END_LINE <= c_LOW;
				//96
				if (r_H_COUNTER < c_H_SYNC_CYCLES) begin
					r_H_COUNTER <= r_H_COUNTER + 1;
					r_H_STATE <= s_H_SYNC;
				end else begin
					r_H_COUNTER <= 0;
					r_H_STATE <= s_H_BACK;
				end
				
			end
			
		s_H_BACK:
			begin
				o_HSYNC_SIG <= c_HIGH;
				
				if (r_H_COUNTER < c_H_BACK_CYCLES) begin
					r_H_COUNTER <= r_H_COUNTER + 1;
					r_H_STATE <= s_H_BACK;
				end else begin
					r_H_COUNTER <= 0;
					r_H_STATE <= s_H_ACTIVE;
				end
				
				//set the end line signal to high
				//one clock cycle offset for synchronous transition
				if (r_H_COUNTER < (c_H_BACK_CYCLES - 1)) begin
					r_END_LINE <= c_LOW;
				end else begin
					r_END_LINE <= c_HIGH;
				end
			end
		default: 
			begin
				//hsync signal high most of the times
				o_HSYNC_SIG <= c_HIGH;
				r_END_LINE <= c_LOW;
				r_H_COUNTER <= 0;
			end
		endcase
		
		case (r_V_STATE)
		s_V_ACTIVE: 
			begin
				o_VSYNC_SIG <= c_HIGH;
				
				if (r_END_LINE == c_HIGH) begin
					if (r_V_COUNTER < c_V_ACTIVE_CYCLES) begin
						r_V_COUNTER <= r_V_COUNTER + 1'd1;
						r_V_STATE <= s_V_ACTIVE;
					end else begin
						r_V_COUNTER <= 0;
						r_V_STATE <= s_V_FRONT;
					end
				end else begin
					r_V_COUNTER <= r_V_COUNTER;
					r_V_STATE <= s_V_ACTIVE;
				end
			
			end
		s_V_FRONT:
			begin
				o_VSYNC_SIG <= c_HIGH;
				
				if (r_END_LINE == c_HIGH) begin
					if (r_V_COUNTER < c_V_FRONT_CYCLES) begin
						r_V_COUNTER <= r_V_COUNTER + 1'd1;
						r_V_STATE <= s_V_FRONT;
					end else begin
						r_V_COUNTER <= 0;
						r_V_STATE <= s_V_SYNC;
					end
				end else begin
					r_V_COUNTER <= r_V_COUNTER;
					r_V_STATE <= s_V_FRONT;
				end
			end
		s_V_SYNC:
			begin
				o_VSYNC_SIG <= c_LOW;
				
				if (r_END_LINE == c_HIGH) begin
					if (r_V_COUNTER < c_V_SYNC_CYCLES) begin
						r_V_COUNTER <= r_V_COUNTER + 1'd1;
						r_V_STATE <= s_V_SYNC;
					end else begin
						r_V_COUNTER <= 0;
						r_V_STATE <= s_V_BACK;
					end
				end else begin
					r_V_COUNTER <= r_V_COUNTER;
					r_V_STATE <= s_V_SYNC;
				end
			end
		s_V_BACK:
			begin
				o_VSYNC_SIG <= c_HIGH;
				
				if (r_END_LINE == c_HIGH) begin
					if (r_V_COUNTER < c_V_BACK_CYCLES) begin
						r_V_COUNTER <= r_V_COUNTER + 1'd1;
						r_V_STATE <= s_V_BACK;
					end else begin
						r_V_COUNTER <= 0;
						r_V_STATE <= s_V_ACTIVE;
					end
				end else begin
					r_V_COUNTER <= r_V_COUNTER;
					r_V_STATE <= s_V_BACK;
				end
			end
		default: 
			begin
				//vsync signal high most of the times
				r_V_COUNTER <= 0;
				r_V_STATE <= s_V_ACTIVE;
				r_V_COUNTER <= 0;
			end
		endcase
		
		//if they are in horizontal and vertical active states
		if (r_H_STATE == s_H_ACTIVE) begin
			if (r_V_STATE == s_V_ACTIVE) begin
				o_Red <= {i_RGB [7:5], 1'b0};
				o_Green <= {i_RGB [4:2], 1'b0};
				o_Blue <= {i_RGB [1:0], 2'b00};
				//during front and back porch
			end else begin
				o_Red <= 4'b0;
				o_Green <= 4'b0;
				o_Blue <= 4'b0;
			end
		end else begin
			o_Red <= 4'b0;
			o_Green <= 4'b0;
			o_Blue <= 4'b0;
		end

	end

	end


endmodule