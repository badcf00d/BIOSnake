# BIOSnake

A boot sector snake game written in x86 NASM assembly for BIOS, it is smaller than 440 bytes (435 to be exact) so it can be flashed into the boot sector of any existing MBR or GPT formatted drive and you'd never know about it until you decide to boot to the drive from a BIOS.

#### How to use:
  - Clone the repository then use the python script from `py-boot-sector` to flash `snake.img` onto your drive, and boot to it from the BIOS.
  - Or if you prefer, use qemu to boot `snake.img` with `qemu-system-x86_64 -drive file=snake.img,format=raw`.

##### Known ~~Bugs~~ *Features*:
  - Food can spawn inside the digits of the score
