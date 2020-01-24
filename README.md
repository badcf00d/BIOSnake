# BIOSnake

A boot sector snake game written in x86 NASM assembly for BIOS, it is smaller than 440 bytes (439 to be exact) so it can be flashed into the boot sector of any existing MBR or GPT formatted drive and you'd never know about it until you decide to boot to the drive

##### Known ~~Bugs~~ *Features*:
  - If the snake passes through the score, the tail will stop moving
