# Custom RISC V RV32I CPU Project
By: Karthikraj Maheshkumar

## Developmental Steps
#### 1.) Project Definition Stage 
#### 2.) Datapath Development Stage
#### 3.) RTL Design and Verification Stage
#### 4.) Physical Layout and Routing

<br>

## Project Definition Stage and Target Technical Objectives 
 - Design a small Harvard architecture CPU from RTL -> GDS2 stage using the RISC V RV32I ISA.
 - CPU will implement 8 instructions of the RISC V RV32I ISA:
   - ADD
   - SUB
   - AND
   - OR
   - ADDI
   - LW
   - SW 
   - BEQ
     
After RTL design and verification, the processor will be implemented using 45 nm PDK. Cadence Genus, Cadence Innovus and Cadence Virtuouso will be the primary tools for synthesis and physical layout. 

<br>

## Datapath and Pipeline Stages 
The following datapath shows the pipeline stages and Hazard Detection/Forward Detection unit signals of the processor:
<img width="2122" height="1110" alt="DataPath1 drawio" src="https://github.com/user-attachments/assets/e3d956f6-5a1b-4d58-8d24-d09e3a08ace3" />

The following datapath shows the pipelined stages, HDU, FDU along with the CU signals. 
<img width="2461" height="1619" alt="DataPath1 drawio (1)" src="https://github.com/user-attachments/assets/e91dc65a-147b-4777-a7bd-f5e2ccc11398" />

<br><br>

# RTL Development and Verification
The CPU was developed using SystemVerilog, and 13 submodules were developed which were subsequently integrated in the top level testbench. The testing and verification process involved writing RISC V assembly code and uploading the equivalent machine code (which was in a .mem file) to the CPU. Various assembly instructions pertaining to the ALU operations, load, store, hazard detection, forward detection, integrated tests and ALU/branch testing. The specific RISC V assembly code, equivalent machine code and subsequent test results are detailed below:

<br>

## Basic ALU Test 

### Assembly Code For Test
<img width="198" height="165" alt="image" src="https://github.com/user-attachments/assets/3b0460df-789d-4a20-94b2-761980f13906" />

### Assembly Machine Code 
<img width="102" height="163" alt="image" src="https://github.com/user-attachments/assets/c1ea2a16-7278-48d5-9d55-bc0303c39239" />

### Test Script and Waveform Results 
<img width="397" height="719" alt="ALU_Test_Script" src="https://github.com/user-attachments/assets/2d29ecc3-a334-4dad-be17-0bbb7678bd60" />

<img width="1408" height="1216" alt="ALU_Test_Waveforms" src="https://github.com/user-attachments/assets/9ca5b246-b2d6-4c36-b727-450c4a9dacd3" />

### Bugs Found and Fixes
Bug: Data write back was happening at same time as access, causing previous data being used, not the most updated recent data.
Fix: Code changed to check for WriteReg == reg1, and if condition met do data == reg[WriteReg]

<br>

## Load and Store 

### Assembly Code For Test
<img width="227" height="102" alt="image" src="https://github.com/user-attachments/assets/30c3fa5e-f557-417b-849e-8be807b2917d" />

### Assembly Machine Code 
<img width="172" height="95" alt="image" src="https://github.com/user-attachments/assets/cf2951fe-749e-4f41-977a-9105543ff6b2" />

### Test Script and Waveform Results 
<img width="436" height="268" alt="Load_Store_Script" src="https://github.com/user-attachments/assets/24f18b85-7c53-4b6c-b318-bd83ab75d3d3" />

<img width="1409" height="1207" alt="Load_Store_Waveforms" src="https://github.com/user-attachments/assets/24ecd6ab-b1d9-419f-a81f-ff3d8545c2c8" />

### Bugs Found and Fixes
Bug: old ReadData being seen because DataMem read was asynchronous: it was available only after MEM/WB captured value.
Fix: MemRead was made synchronous.

<br>

## Load Use Hazard Test

### Assembly Code For Test
<img width="122" height="48" alt="image" src="https://github.com/user-attachments/assets/5a0250ae-0687-4549-88a5-2f20151c4da3" />

NOTE: 42 was preloaded onto DataMem[5]

### Assembly Machine Code 
<img width="154" height="76" alt="image" src="https://github.com/user-attachments/assets/f48d689a-6665-497a-b7c6-a50e6bbb5307" />

### Test Script and Waveform Results 
<img width="444" height="283" alt="Load_Use_Hazard_Script" src="https://github.com/user-attachments/assets/eb15aa1f-ec76-4afd-bc2c-97d825834ec6" />

<img width="1370" height="1151" alt="Load_Use_Hazard_Waveform" src="https://github.com/user-attachments/assets/1ab8402c-5129-4f9b-b30b-28679848f55b" />

### Bugs Found and Fixes
No bugs found.

<br>

## Forwarding Verification
For this test, 2 sub-tests were conducted:
 - Test 1, EX/MEM to EX forwarding
 - Test 2, MEM/WB forwarding

## Forwarding Verification Test 1: EX/MEM Forwarding 

### Assembly Code For Test
<img width="228" height="125" alt="image" src="https://github.com/user-attachments/assets/11894a6f-4515-4e3d-a36f-f42ab9ba6d98" />

NOTE: in the above code, X3 from the add x3, x1, x2 instruction needs to be forwarded from EX/MEM register so that sub x4, x3, x1  instruction can use.

### Assembly Machine Code 
<img width="128" height="126" alt="image" src="https://github.com/user-attachments/assets/81fb0199-c513-443f-818c-7e358cd877e6" />

### Test Script and Waveform Results 
<img width="469" height="308" alt="EX_MEM_Forwarding_Script" src="https://github.com/user-attachments/assets/870306c4-4ec1-4abd-b6dd-6124d11fdc49" />

<img width="1296" height="1156" alt="EX_MEM_Forwarding_Waveform" src="https://github.com/user-attachments/assets/2fd47193-dff3-438e-afc5-655b3a8a14d1" />

### Bugs Found and Fixes
No bugs found.

<br>

## Forwarding Verification Test 2: MEM/WB Forwarding 

### Assembly Code For Test
<img width="231" height="163" alt="image" src="https://github.com/user-attachments/assets/f7cdcb3a-0a09-4051-89df-569ceae592d8" />

NOTE: in the above code, X3 from the add x3, x1, x2 instruction needs to be forwarded from MEM/WB register so that sub x4, x3, x1  instruction can use x3.

### Assembly Machine Code 
<img width="130" height="159" alt="image" src="https://github.com/user-attachments/assets/92c09eb3-cba8-4ee6-b930-c8e09e3489e4" />

### Test Script and Waveform Results 
<img width="462" height="378" alt="MEM_WB_FORWARD_Script" src="https://github.com/user-attachments/assets/6ef430c2-33f7-4155-9190-a41d241a4add" />

<img width="1388" height="1177" alt="MEM_WB_Forward_Waveform" src="https://github.com/user-attachments/assets/7ff91887-48f0-4d80-a45d-e3331d7de53c" />

### Bugs Found and Fixes
No bugs found.

<br>

## Branching Verfication

### Assembly Code For Test
<img width="124" height="88" alt="image" src="https://github.com/user-attachments/assets/03b9fa09-2609-4aeb-80fa-b055130d353f" />

NOTE: in the above code, addi x3, x0, 99 must be skipped due to beq x1, x2, +8 instruction executing.

### Assembly Machine Code 
<img width="67" height="89" alt="image" src="https://github.com/user-attachments/assets/5adf853b-717d-413d-bc36-22d6496c34ca" />

### Test Script and Waveform Results 
<img width="1272" height="797" alt="Branch_Waveform_Test" src="https://github.com/user-attachments/assets/f2d5cb3c-40a9-4006-950e-5db547ed6676" />


### Bugs Found and Fixes
Bug: x3 expected 0, but got 99. This was because addi x3, x0, 99 already had entered the ID/EX register by the time branch flush had become 1 which means that the register value for x3 had already been changed before the branch flush signal could reach the registers and void the numbers. The fix was to re-write the branching logic to use ALU_Zero which updated synchronously (instead of EX/MEM_ALU_Zero which updated asynchronously) and send the branching signal from ID/EX instead of EX/MEM, that way the instruction coming after the branch could immediately be flushed once the branch is detected and ALU_Zero is true.

 <br>

## Combined/Integrated Program

### Assembly Code For Test
<img width="423" height="196" alt="image" src="https://github.com/user-attachments/assets/a4252733-f6f1-42ba-bee2-9588c70aace3" />

 

### Assembly Machine Code 
<img width="81" height="216" alt="image" src="https://github.com/user-attachments/assets/00d0b660-c17c-477c-9612-814f9d8d9030" />

 

### Test Script and Waveform Results 
<img width="786" height="451" alt="CPU_Integration_Test_Script" src="https://github.com/user-attachments/assets/bb8cd6e2-63b6-4786-866a-5967c848ab0f" />

<img width="1170" height="782" alt="CPU_Integration_Test_Waveform" src="https://github.com/user-attachments/assets/a37ed7eb-32db-4656-beca-6452873e7121" />

 

### Bugs Found and Fixes
No bugs found.

 <br>

## BEQ Dependence on ALU Forwarding Test

 

### Assembly Code For Test
<img width="220" height="177" alt="image" src="https://github.com/user-attachments/assets/7d0293e1-7d09-44b6-819f-cd581570aefd" />

NOTE: In the code above, the beq x3, x3, +8 instruction has an immediate dependency on x3 from the add x3, x1, x2 instruction, necessitating the need for forwarding to make the updated x3 value available for the beq instruction.

 

### Assembly Machine Code 
<img width="117" height="183" alt="image" src="https://github.com/user-attachments/assets/3c95c94d-b218-477a-b9ee-02bb5fd5ba4e" />

 

### Test Script and Waveform Results 
<img width="822" height="347" alt="Branch_Forward_Test_Script" src="https://github.com/user-attachments/assets/80420d4b-6cdc-46ad-9dcb-721fc8f23068" />

<img width="1257" height="772" alt="Branch_Forward_Test_Waveform_1" src="https://github.com/user-attachments/assets/fb71ef08-bf65-4dfd-ac02-2a4700df2bd3" />

<img width="1271" height="772" alt="Branch_Forward_Test_Waveform_2" src="https://github.com/user-attachments/assets/abe6af6e-a01e-4378-ab71-8f5799aeba9c" />


### Bugs Found and Fixes
No bugs found.

<br><br>

## Synthesis Results on Cadence Genus
After the verification of the CPU on ModelSim using uploaded machine code via the testbench, the CPU was then taken through the synthesis process on Cadence Genus using the GPDK045 process technology. Several errors and difficulties were encountered in this stage:
 - Initially, the top level had not assigned any outputs, which caused the Genus tool to assign large chunks of the CPU as irrelevant logic (as it did not see them driving any external output or being driven by an external input). The top level file had to be edited such that some outputs were assigned without changing any logic associated with the CPU function.
 -  Lack of external driving signals caused the memory array in the InstructionMem to be deleted. To fix this, an asynchronous reading mechanism was added where external inputs were added to asynchronously read data into the instruction memory array, while the memory read remained synchronous so as not to change the logic structure.

After fixing the issues encountered, the RTL for the CPU was succesfully synthesized using Cadence Genus targeting the GPDK045 standard-cell library.  The synthesis flow considted of generic synthesis (syn_generic_, technology mapping (syn_map), and post mapping optimization (syn-opt). Timing constraints were applied for a 333 MHz target clock.

<br>

### Synthesis Flow
<img width="222" height="727" alt="Synthesis_Flow_Diagram drawio" src="https://github.com/user-attachments/assets/ad88b972-1f06-432e-afee-a4f2bbc3da51" />

 <br>

### Timing Constraints
<img width="631" height="171" alt="image" src="https://github.com/user-attachments/assets/3448f6ed-802c-4a4f-868a-f45ba9104f48" />

 <br>

### Synthesis Results

 <br>

#### Timing Results 
<img width="936" height="129" alt="image" src="https://github.com/user-attachments/assets/19568054-e4e6-47ea-9b23-8ce561aedb8e" />

The result above is from the timing report generated from the Synthesis. As shown, the worst setup slack time is approximately +0.101 ns and the associated path is from the EX/MEM Pipeline register -> PC. The positive slack time is indicative that the CPU is functional at the target frequency of 333 MHz, and a lower frequency optimization is not necessary.

 <br>

#### Area Results
<img width="700" height="302" alt="Synthesis_Area_Report" src="https://github.com/user-attachments/assets/34bfdaf8-6c5c-41f4-bad7-29d88e95ce7a" />

The standard cell area after synthesis generation and optimization for the CPU was 34,149.726 um^2, with the Data Memory module contributing the most area at 9,863.964 um^2, which is likely due to the use of many flip-flops for the 32x32 memory array in the Data Memory. 

 <br>

#### Gate Use Reports
<img width="397" height="247" alt="Synthesis_Gate_report" src="https://github.com/user-attachments/assets/4697c4f6-20a8-49b8-963a-d1f75e5d6913" />

From the gate use reports, it can be seen that the sequential logic gates take up the vast majority of the core area at a whopping 77%. This is likely due to the large use of memory arrays in the Instruction Memory and Data Memory as well as large pipeline registers. The relatively smaller contribution of the logic gates can be attributed to the smaller number of logic operations being implemented (only 8 RV32I logical operations were implemented). 

 <br>

#### Critical Path Analysis
As stated previously, the critical path of the CPU was of the following nature:
 - Critical Path Type: register-register
 - Startpoint: ex_mem_module_rd_out_reg[1]
 - Endpoint: pc_module_pc_reg[31]
 - Worst Slack: +0.101 ns

<img width="935" height="130" alt="Genus_Timing_Report" src="https://github.com/user-attachments/assets/fe230af1-8bb7-4591-b3d8-ecd875cccd27" />

The worst setup path propagates from EX/MEM pipeline register through combinational logic into the PC register. At the set clock period target of 3.003 ns, the critical path meets timing with +101 ps of remaining setup margin. 

 <br>

#### Critical Path Schematic
<img width="717" height="933" alt="CPU_Critical_path_image" src="https://github.com/user-attachments/assets/082184c1-9616-41ce-a1bf-69961e8fda13" />

 <br>

#### Check_Design Results
<img width="1191" height="645" alt="CPU_Synthesis_Check_Design" src="https://github.com/user-attachments/assets/f22cf444-6a18-4485-9c89-fcb54c36208a" />

Post synthesis check_design reported no unresolved references, undriven ports, multidrive nets, unloaded sequential pins or other logic connectivity errors. 

 <br>

#### Synthesized CPU Schematic
<img width="2559" height="1237" alt="Synthesized_CPU" src="https://github.com/user-attachments/assets/c7f2fc39-7893-4523-9270-f77cd6754e01" />

<img width="242" height="714" alt="Synthesized_CPU_Closeup" src="https://github.com/user-attachments/assets/34974e50-624d-4779-a8ea-bb506c832b3f" />

<br>

#### Summary
The synthesis and subsequent reports showed the large contribution of sequential memory elements (likely in the form of flip flops) to the cell area size. However, these are pre-layout estimates, which means that the timing, area, and power will have to be checked again after placement, clock-tree synthesis, routing and parasitic extraction in Cadence Innovus. 

<br><br>

## Place and Route Results
The generated netlist from Cadence Genus was then taken through the PnR process utilizing Cadence Innovus. The floorplan, CTS structure, CTS skew, critical setup path, critical hold path, post-route power and final DRC, connectivity and antenna figures are detailed below.

 <br>
 
### Floorplan Figures

<img width="839" height="1062" alt="PnR_Floorplan_Wirelength" src="https://github.com/user-attachments/assets/91f399db-91ce-4ae3-bf2d-9f5fca929992" />

 <br>

### CTS Structure

<img width="1198" height="828" alt="PnR_CTS_Report_1" src="https://github.com/user-attachments/assets/e7dae487-6fa9-43d9-86f9-32a71bb00f16" />

 <br>

### CTS Skew 
<img width="1522" height="347" alt="CPU_CLock_Ckew" src="https://github.com/user-attachments/assets/b6f2141b-8df4-4791-8d1d-bb9f424d8482" />

<br>

### Critical Setup Path

<img width="750" height="442" alt="PnR_Critical_Setup_Time" src="https://github.com/user-attachments/assets/e9d77e8d-863e-4cb1-954a-8f556163d461" />

 <br>
 
### Critical Hold Path

<img width="949" height="576" alt="PnR_Critical_Hold_Path" src="https://github.com/user-attachments/assets/8c8ab856-a8de-4da7-aaa9-64ac2859ff0e" />

 <br>
 
### Post Route Power

<img width="1298" height="952" alt="PnR_Power_1" src="https://github.com/user-attachments/assets/639ef215-c7ce-4699-a036-232e1cb56f84" />

<img width="866" height="829" alt="PnR_Power_2" src="https://github.com/user-attachments/assets/172be2c0-6bb0-40ec-9abb-8b8f5ffaccf3" />

 <br>
 
### Final DRC Check

<img width="779" height="1030" alt="Final_DRC_Check" src="https://github.com/user-attachments/assets/1fe71384-1416-457a-96bb-699ff4fbed66" />

 <br>
 
### Final Connectivity Check

<img width="499" height="486" alt="Final_verify_connectivity" src="https://github.com/user-attachments/assets/0b73547c-8bf1-4a33-9e6c-e75c732bfc1a" />

 <br>
 
### Final Antenna Check

<img width="690" height="229" alt="Verify_Antenna_Check" src="https://github.com/user-attachments/assets/40c0f2a9-b9d1-4827-a123-6e4b6da44a0b" />

 <br>
 
### GDS2 Stream Out 

<img width="464" height="992" alt="GDS2StreamOutData" src="https://github.com/user-attachments/assets/a7b564cd-59d8-4919-a864-5539233487f3" />

 <br>
 
### Final Routed Layout Image

<img width="900" height="950" alt="CPU_Pic" src="https://github.com/user-attachments/assets/a40b69f0-15fb-4d8d-980e-fac718fd2284" />


























