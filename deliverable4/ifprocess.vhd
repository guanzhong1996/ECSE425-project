--********************************************************************
-- ECSE 425, Group 6
-- Zhong GUAN(260758587)
-- Date: March 14, 2017

-- Description: The IF stage is where a program counter will
-- pull the next instruction from the correct location in program memory.
-- This instruction is written into the IF/ID register at the next positive clock cycle. 
-- In addition the program counter was updated with 
-- either the next instruction location sequentially, 
-- or the instruction location as determined by a branch

--********************************************************************


LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE STD.textio.all;
USE ieee.std_logic_textio.all;

ENTITY ifprocess IS
	GENERIC(
		ram_size : INTEGER := 4096;
		mem_delay : time := 1 ns;
		clock_period : time := 1 ns
	);
	PORT(
		clock: IN STD_LOGIC;
		reset: in std_logic := '0';
		processor_enable: in std_logic := '1';
		insert_stall: in std_logic := '0';
		BranchAddr: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		Branch_taken: IN STD_LOGIC := '0';
		next_addr: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		--memory
		memread: IN STD_LOGIC;
		inst: out std_logic_vector(31 downto 0)
	);
END ifprocess;

ARCHITECTURE behavioral of ifprocess IS
	TYPE MEM IS ARRAY(ram_size-1 downto 0) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ram_block: MEM;
	SIGNAL read_address_reg: INTEGER RANGE 0 to ram_size-1;
	SIGNAL waitrequest: STD_LOGIC := '1';
	signal line_counter: integer := 0;

	signal pc: STD_LOGIC_VECTOR (31 DOWNTO 0):= (others => '0');
	signal next_pc: STD_LOGIC_VECTOR (31 DOWNTO 0):= (others => '0');
	signal pc_plus4: STD_LOGIC_VECTOR (31 DOWNTO 0);
	signal block_data: STD_LOGIC_VECTOR(31 DOWNTO 0);
begin
	--Read the 'program.txt' file into instruction memory
	readprogram: process
		file program: text;
		variable mem_line: line;
		variable read_data: std_logic_vector(31 downto 0);
	begin
		file_open(program,"program.txt", read_mode);
		IF (clock'event AND clock = '1') THEN
			while not endfile(program) loop
				readline(program,mem_line);
				read(mem_line,read_data); --32bits data
				block_data <= read_data;
				for i in 0 to 3 loop
					ram_block(line_counter) <= block_data(7+8*i downto 0 + 8*i);
					line_counter <= line_counter+1;
				end loop;
			end loop;
		file_close(program);
		end if;
	end process;

	process (clock)
	begin
		--Initialize the SRAM in simulation
		IF(now < 1 ps)THEN
			For i in 0 to ram_size-1 LOOP
				ram_block(i) <= std_logic_vector(to_unsigned(i,8));
			END LOOP;
		end if;

		if(rising_edge(clock)) then
			--Synchronous reset
			if (reset = '1') then
				pc <= (others => '0');
			--Update PC as long as we don't stall
			elsif (processor_enable = '1') and (insert_stall = '0') then
				pc <= next_pc;
				pc_plus4 <= std_logic_vector(unsigned(pc) + 4);
				read_address_reg <= to_integer(unsigned(pc));
			end if;
		end if;

		if(falling_edge(clock)) then
			if(Branch_taken = '1') then
				next_addr <= BranchAddr;
				next_pc <= BranchAddr;
			else 
				next_addr <= pc_plus4;
				next_pc <= pc_plus4;
			end if;
			-- read data
			if (waitrequest = '1') then
				inst(31 downto 24) <= ram_block(read_address_reg);
				inst(23 downto 16) <= ram_block(read_address_reg+1);
				inst(15 downto 8) <= ram_block(read_address_reg+2);
				inst(7 downto 0) <= ram_block(read_address_reg+3);
			end if;
		end if;
	end process;
	
	waitreq_r_proc: PROCESS (memread)
	BEGIN
		IF(memread'event AND memread = '1')THEN
			waitrequest <= '0' after mem_delay, '1' after mem_delay + clock_period;
		END IF;
	END PROCESS;

end behavioral;