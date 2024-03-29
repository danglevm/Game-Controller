module SPI_MASTER

#(parameter c_SPI_MODE = 3, //SPI_mode is 3, so CPOL = 1 and CPHA = 1, can be changed later
	/***********************
	clocking
	system clock - 50 MHz
	SPI clock - 12.5 MHz - recommendation for an 8-bit MCU, don't know if it applies here
	clocks per bit - 4 clks/bit
	clocks per half bit - 2clks
	***********************/
	
  parameter c_CLKS_PER_HALF_BIT = 2)
(
	input i_CLK,
	input i_RESET_n,
	
	
	/************************
	both MOSI and MISO viewed from a higher level module perspective
	*************************/
	//MOSI - TX - master get data from higher-level
	input [7:0] i_TX_BYTE,
	input i_TX_DV,
	output reg o_TX_READY, //ready to accept input from higher-level module
	
	
	//MISO - RX - master receives data from slave, then outputs it to higher level
	output reg o_RX_DV,
	output reg [7:0] o_RX_BYTE,
	
	/**********************
		SPI interface - writing onto data lines
	***********************/
	input  i_SPI_MISO,
	output reg o_SPI_CLK,
	output reg o_SPI_MOSI
	
);

/**************************
        Wires
**************************/
wire w_CPOL = 0;
wire w_CPHA = 0;

/**************************
        Registers
**************************/
//store number of edges
reg [3:0] r_CLK_EDGES_PER_BYTE = 16;

//tell the SPI clock to send out a signal to shift or read incoming bits
//here falling or rising edge doesn't matter == CPOL doesn't matter because the bit read/shift operation is done only during leading/trailing edge 
reg r_LEADING_EDGE = 1'b0;
reg r_TRAILING_EDGE = 1'b0;

reg [3:0] r_TX_BIT_INDEX = 8; //starts from MSb
reg [3:0] r_RX_BIT_INDEX = 8; //starts from MSb
reg [3:0] r_CLK_CNT = 0; 
reg r_TX_DV = 0;




/**************************
        Parameters
**************************/
localparam c_EDGE_PER_BYTE = 16;
localparam c_HIGH = 1'b1;
localparam c_LOW = 1'b0;

/**************************
			Assignment
***************************/

//bitwise operators - one of them correct and it's good
assign w_CPOL = (c_SPI_MODE == 2) | (c_SPI_MODE == 3);
assign w_CPHA = (c_SPI_MODE == 1) | (c_SPI_MODE == 3);




/****************************
		Generate SPI trailing and falling edges
*****************************/

always @ (posedge i_CLK or negedge i_RESET_n) begin
	
	if (~i_RESET_n) begin
		o_TX_READY <= c_LOW;
		r_CLK_CNT <= c_LOW;
		r_LEADING_EDGE <= c_LOW;
		r_TRAILING_EDGE <= c_LOW;
		r_CLK_EDGES_PER_BYTE <= 16;
	
	end else begin 
		r_LEADING_EDGE <= c_LOW;
		r_TRAILING_EDGE <= c_LOW;
	
		//default state so set trailing edges to default
		if (o_TX_READY == c_HIGH) begin
			r_CLK_EDGES_PER_BYTE <= 16;	
		//countdown from 16 edges
		end else if (r_TRAILING_EDGE > 0) begin
		//data sent in from higher module is ready
			if (i_TX_DV) begin 
				//at the end of the second half of the clock cycle
				if (r_CLK_CNT == (c_CLKS_PER_HALF_BIT*2 - 1)) begin
					r_CLK_CNT <= 0;
					r_LEADING_EDGE <= c_LOW;
					r_TRAILING_EDGE <= c_HIGH;
					r_CLK_EDGES_PER_BYTE <= r_CLK_EDGES_PER_BYTE - 1;
				//takes one clock cycle to add the value then another clock cycle to resolve this so -1
				end else if (r_CLK_CNT == (c_CLKS_PER_HALF_BIT - 1)) begin
					//send leading edge signal
					r_LEADING_EDGE <= c_HIGH;
					r_TRAILING_EDGE <= c_LOW;
				end else begin
					r_CLK_CNT <= r_CLK_CNT + 1;
				end		
				
		end else if (r_TRAILING_EDGE == 0) begin
			//all 16 edges passed through, so one byte is sent and another can be taken in now
				o_TX_READY <= c_HIGH;
			end
		
		end //TX_DV
	
	end //if reset
	
end //always



/****************************
		MOSI
*****************************/
always @ (posedge i_CLK or negedge i_RESET_n) begin
	
	if (i_RESET_n) begin
		o_SPI_MOSI <= c_LOW;
		r_TX_BIT_INDEX <= 3'b111;
	
	end else begin 
				
		//data signal ready, on standby to receive new data
		if (o_TX_READY) begin
			r_TX_BIT_INDEX <= 3'b111;
			
	/*	else if (i_TX_DV && ~w_CPHA) begin
			o_SPI_MOSI <= r_TX_BYTE[3'b111];
			r_TX_BIT_INDEX <= 3'b110;*/
			
		//CPHA = 1 --> trailing edge. CPHA = 0 --> leading edge
		//sample data from input parallel bits
		end else if ((r_TRAILING_EDGE && w_CPHA) || (r_LEADING_EDGE && ~w_CPHA)) begin
			o_SPI_MOSI <= i_TX_BYTE [r_TX_BIT_INDEX];
			r_TX_BIT_INDEX <= r_TX_BIT_INDEX - 1;
		end
		
	
	end //if reset
	
end //always


/****************************
		MISO
*****************************/
always @ (posedge i_CLK or negedge i_RESET_n) begin
	
	if (i_RESET_n) begin
		o_RX_BYTE <= 8'b00000000;
		o_RX_DV <= c_LOW;
		r_TX_BIT_INDEX <= 3'b111;
	
	end else begin 
		
		//in default state
		if (o_TX_READY) begin
			r_TX_BIT_INDEX <= 3'b111;
		
		end else if ((r_LEADING_EDGE && w_CPHA) || (r_TRAILING_EDGE && ~w_CPHA)) begin
		//send data from miso line onto out into rx
			o_RX_BYTE [r_RX_BIT_INDEX] <= i_SPI_MISO;
			r_RX_BIT_INDEX = r_RX_BIT_INDEX - 1;
			
			if (r_RX_BIT_INDEX == 0) begin
				o_RX_DV <= c_HIGH;
			end
		end
		
	
	end //if reset
	
end //always


endmodule