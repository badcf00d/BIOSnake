from time import gmtime, strftime




backupName = "bootsector-"
backupName += strftime("%d-%m-%Y-%H-%M-%S", gmtime())
backupName += ".bin"

backup = open(backupName, "ab")

# customize there
newFile = open("bootsector - 21-01-2020-22-49-40.bin", "rb")
disk = open(r'\\.\PhysicalDrive3', 'r+b')



disk.seek(0)
oldBootloader = disk.read(512)
backup.write(oldBootloader)
print("Old bootloader: \n")
print(oldBootloader.hex())

newBootloader = newFile.read(512)
print("New Bootloader: \n")
print(newBootloader.hex())

disk.seek(0)
#disk.write(newBootloader)

#disk.seek(OFFSET * 512)
#disk.write(data)
