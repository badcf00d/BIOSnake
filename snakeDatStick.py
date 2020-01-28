from time import gmtime, strftime
import os

newFile = open("snake.img", "rb")
newBootloader = bytearray(newFile.read())

if len(newBootloader) > 440: 
    print("This image is too big: ", len(newBootloader))
    raise SystemExit

for i in range(len(newBootloader), 440):
    newBootloader.append(0)

backupName = "bootsector-"
backupName += strftime("%d-%m-%Y-%H-%M-%S", gmtime())
backupName += ".bin"

#backup = open(backupName, "ab")
#disk = open(r'\\.\PhysicalDrive3', 'r+b')

disk.seek(0)
oldBootloader = disk.read(512)
backup.write(oldBootloader)
print("Old bootloader: \n")
print(oldBootloader.hex())

partitionTable = oldBootloader[440:512]
newBootloader.append(partitionTable)


print("New Bootloader: \n")
print(newBootloader.hex())

disk.seek(0)
disk.write(newBootloader)

