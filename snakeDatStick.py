from time import gmtime, strftime
import os
import wmi
import tkinter as tk
from tkinter import filedialog


input("\nHi,\n\nYou're about to pick the file you want to flash, press enter to continue")

#   Open up a dialog box to pick a file to flash
root = tk.Tk()
root.withdraw()
filePath, fileExtension = os.path.splitext(filedialog.askopenfilename())

#   Decide if this is a game image or a backup
newImageLength = None
if (fileExtension == ".img"):
    newImageLength = 440
elif (fileExtension == ".bak"):
    newImageLength = 512
else:
    print("Not sure what file type this is, please use .img for game images, .bak for backups")
    raise SystemExit

#   Load the new file
newFile = open(filePath + fileExtension, "rb")
newBootloader = bytearray(newFile.read())

#   Length check
if len(newBootloader) > newImageLength: 
    print("Images can't be bigger than %d bytes, this is %d" % (newImageLength, len(newBootloader)))
    raise SystemExit
else:
    print("That was: \"%s%s\", %d bytes\n\n" % (filePath, fileExtension, len(newBootloader)))



input("Now pick the drive you want to flash (probably a USB stick), press enter to continue")

#   Open a dialog box to pick a target drive
targetDrivePath = filedialog.askdirectory()
targetDrive = None

for physicalDisk in wmi.WMI().Win32_DiskDrive(InterfaceType='USB'):
    for partition in physicalDisk.associators("Win32_DiskDriveToDiskPartition"):
        for logicalDisk in partition.associators("Win32_LogicalDiskToPartition"):
            #print(physicalDisk.Caption, physicalDisk.DeviceID, logicalDisk.Caption)

            if targetDrivePath[0] == logicalDisk.Caption[0]:
                confirm = input("You selected \"%s\" is this correct? (y/n)" % physicalDisk.Caption)

                if confirm == "y":
                    targetDrive = physicalDisk.DeviceID
                else:
                    raise SystemExit

if targetDrive == None:
    print(  "I don't think that was a USB stick, you probably don't want to flash your hard drive with"
            "this because it probably has your operating system on it, but if you must, change the"
            "InterfaceType in the python script to HDC or something")
    raise SystemExit



#   Pad the file with zeros if it is shorter than we need
for i in range(len(newBootloader), newImageLength):
    newBootloader.append(0)



#   Create the backup file
backupName = "bootsector-"
backupName += strftime("%d-%m-%Y-%H-%M-%S", gmtime())
backupName += ".bak"
backup = open(backupName, "ab")


#   Load the bootloader from the target drive
#disk = open(r'\\.\PhysicalDrive3', 'r+b')
disk = open(targetDrive, 'r+b')
disk.seek(0)
oldBootloader = disk.read(512)
backup.write(oldBootloader)
print("Old bootloader: \n")
print(oldBootloader.hex())


#   If this is a game image we need to merge in the old partition table to our new bootloader
if (fileExtension == ".img"):
    partitionTable = bytearray(oldBootloader[440:510])
    newBootloader.extend(partitionTable)
    newBootloader.append(0x55)
    newBootloader.append(0xaa)


#   Write our new bootloader
print("New Bootloader: \n")
print(newBootloader.hex())
disk.seek(0)
disk.write(newBootloader)
