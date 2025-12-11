run_all: compile
	@for p in $(PROGRAMS); do \
		echo "=== Running $$p ==="; \
		$(MAKE) run_test PROGRAM=$$p; \
	done

compile:
	iverilog -o sim.vvp *.v

PROGRAMS = 01add 02addi 03and 04andi 05lui 06memory \
		   07or 08ori 09sll 10slli 11slt 12slti 13sltiu \
		   14sltu 15sra 16srai 17srl 18srli 19sub 20xor \
		   21xori exhaustive_nobranch factorial_2 factorial_5 sort

run_test:
	cp ./tests/$(PROGRAM).mem program.mem
	vvp sim.vvp > ./traces/$(PROGRAM).txt
