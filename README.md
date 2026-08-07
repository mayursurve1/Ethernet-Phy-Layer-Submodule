# Ethernet-Phy-Layer-Submodule 
### Design and Verification of ethernet phy layer submodule 
### Designed 64/66B encoder, sync.fifo, scrambler, descrambler and decoder
---
##### 64b/66b Encoder – converts 64-bit data into 66-bit encoded blocks.
#### Synchronous FIFO – provides buffering between processing stages.
#### Scrambler – performs self-synchronous scrambling to improve signal characteristics and reduce repetitive patterns.
#### Descrambler – reconstructs the original data from the scrambled stream.
#### Decoder – decodes the 66-bit blocks back into the original 64-bit data.
---
#### UVM-based Verification – developed driver, monitor, sequencer, scoreboard, agent and environment to verify the complete data path.
#### Verified  Encoder stage  functionality also Descrambler functionality
