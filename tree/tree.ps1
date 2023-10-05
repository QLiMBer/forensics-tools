<#
.SYNOPSIS
Generates a tree-like structure of directories and files starting from a specified path and outputs it to a specified text file in UTF-8 encoding.

.DESCRIPTION
This script recursively retrieves and displays the directory structure, including files, from a specified path, and writes it to a text file. It provides a solution for encoding issues encountered with the traditional "tree /f" command, ensuring accurate text output even with non-ASCII characters in file and directory names.

.PARAMETER Path
A string that specifies the path from where the tree structure will be generated. If no path is provided, it defaults to the current directory ("."). 

.PARAMETER OutFile
A string that specifies the path and name of the output file. If no file is provided, it defaults to "tree.txt" in the current directory. If the default file already exists, the user will be prompted to provide a different filename.

.EXAMPLE
. .\tree.ps1 -Path "C:\MyFolder" -OutFile "output.txt"

.NOTES
File Name      : tree.ps1
Author         : QLiMBer & ChatGPT-4
Prerequisite   : PowerShell V3

.LINK
[https://github.com/QLiMBer/forensics-tools/tree/main/tree]

#>

param (
    [string]$Path = ".",
    [string]$OutFile = "tree.txt"
)

function Get-Tree {
    param (
        [string]$Path,
        [int]$Level = 0
    )

    Get-ChildItem -Path $Path | ForEach-Object {
        "$('  ' * $Level)$_"
        if (Test-Path -Path $_.FullName -PathType Container) {
            Get-Tree -Path $_.FullName -Level ($Level + 1)
        }
    }
}

if (Test-Path -Path $OutFile -PathType Leaf) {
    $userInput = Read-Host "`n$OutFile already exists. Please provide a new filename or press Enter to overwrite."
    if ($userInput) {
        $OutFile = $userInput
    }
}

Get-Tree -Path $Path | Out-File -FilePath $OutFile -Encoding utf8
Write-Host "`nTree structure saved to $OutFile"

