from time import gmtime, strftime
import os
import sys
import subprocess
import re
import tkinter as tk
from tkinter import filedialog


#   Open up a dialog box to pick a file to flash
input("\nHi,\n\nYou're about to pick the file you want to flash, press enter to continue")
root = tk.Tk()
root.withdraw()
filePath, fileExtension = os.path.splitext(filedialog.askopenfilename())


#   Decide if this is a game image or a backup
newImageLength = 0
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


#   Open a dialog box to pick a target drive
input("Now pick the drive (probably a USB stick) you want to flash, press enter to continue")
targetDirectory = filedialog.askdirectory()
targetDrive = ""








#
#   This whole block is to determine which physical drive matches the target directory
#
if sys.platform.startswith('linux') or sys.platform.startswith('darwin'):
    import psutil

    if targetDirectory == '/':
        input(  "I'm not sure you want to flash your root drive with this, "
                "That probably has your operating system on it, and you probably "
                "won't be able to boot that operating system any more if you do this")
        raise SystemExit

    partitions = psutil.disk_partitions()
    for part in partitions:
        #   part.mountpoint gives us the device name as in /dev/disk0s0 or /dev/sda or whatever
        if part.mountpoint == targetDirectory:
            confirm = None

            if sys.platform.startswith('linux'):
                targetDrive = part.device[:8]

                #   Uses lshw to list info for all the disks, then uses grep to find the one we want
                output = subprocess.run("sudo lshw -c disk -short | grep -m 1 " + targetDrive, \
                    shell=True, universal_newlines=True, stdout=subprocess.PIPE)

                #   Trim off some of the stuff we don't want to show
                regex = re.search("(?:disk *).*", output.stdout).group()

                #   This will show us our human-friendly device name like Sandisk USB Drive or whatever
                confirm = input("You selected \"%s\" is this correct? (y/n)" % regex[15:])
            else:
                targetDrive = part.device[:10]

                #   Uses diskutil to show the info for our target drive
                output = subprocess.run("diskutil info " + part.device[:10] + " | grep \"Device / Media Name:\"", \
                    shell=True, universal_newlines=True, stdout=subprocess.PIPE)

                #   This will show us our human-friendly device name like Sandisk USB Drive or whatever
                confirm = input("You selected \"%s\" is this correct? (y/n)" % output.stdout[24:].strip())

            print(targetDrive)

            if confirm != "y":
                raise SystemExit


elif sys.platform.startswith('win32'):
    import wmi

    if targetDirectory[0] == 'C':
        input(  "I'm not sure you want to flash the C drive with this, "
                "That probably has your operating system on it, and you probably "
                "won't be able to boot that operating system any more if you do this")
        raise SystemExit

    #   Uses the Win32_DiskDrive WMI class to look through all of the drives until we find the we we want
    for physicalDisk in wmi.WMI().Win32_DiskDrive():
        for partition in physicalDisk.associators("Win32_DiskDriveToDiskPartition"):
            for logicalDisk in partition.associators("Win32_LogicalDiskToPartition"):

                if targetDirectory[0] == logicalDisk.Caption[0]:
                    #   This will show us our human-friendly device name like Sandisk USB Drive or whatever
                    confirm = input("\nYou selected \"%s\" is this correct? (y/n)" % physicalDisk.Caption)

                    if confirm == "y":
                        targetDrive = physicalDisk.DeviceID
                        break
                    else:
                        raise SystemExit

else:
    input("Not got a clue what operating system this is, please make a pull request to fix this")
    raise SystemExit



if targetDrive == "":
    input(  "Hmm, couldn't find a drive matching that directory, please make an " 
            "issue for this, targetDirectory is: \"%s\"" % targetDirectory)
    raise SystemExit









#   Load the bootloader from the target drive
try:
    disk = open(targetDrive, 'r+b')
except PermissionError:
    input("\nDon't seem to have permission to write to that drive, "
            "try running this script with admin / root permissions")
    raise SystemExit

#   Create the backup file
backupName = "bootsector-"
backupName += strftime("%d-%m-%Y-%H-%M-%S", gmtime())
backupName += ".bak"
backup = open(backupName, "ab")

#   Read the old bootloader
disk.seek(0)
oldBootloader = disk.read(512)
backup.write(oldBootloader)
print("Old bootloader: \n")
print(oldBootloader.hex())


#   Pad the file with zeros if it is shorter than we need
for i in range(len(newBootloader), newImageLength):
    newBootloader.append(0)


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
