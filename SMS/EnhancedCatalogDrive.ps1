<# 
.SYNOPSIS
    Catalogs a specified drive by exporting its metadata and file details to separate CSV files with enhanced SSD detection and error handling.

.DESCRIPTION
    This script retrieves metadata for a specified drive and enumerates all accessible files within it.
    The metadata and file details are exported to separate CSV files, named based on the drive's
    Serial Number (SN), whether it's an SSD or HDD, and size in TB. It includes improved logic to detect SSDs,
    especially those connected via USB adapters, and handles access-denied errors gracefully.

.PARAMETER DriveLetter
    The drive letter of the drive to catalog (e.g., "N").

.PARAMETER SerialNumber
    (Optional) The serial number of the drive. If not provided, the script attempts to auto-detect it.

.EXAMPLE
    .\EnhancedCatalogDrive.ps1 -DriveLetter N -SerialNumber "SN1234567890"

.NOTES
    Future Improvement Ideas:

    1) **Explicit SN Logging:**
       - Enhance log files, especially the `_CatalogDrive_Errors.log`, to indicate when the Serial Number (SN)
         was explicitly provided by the user versus auto-detected by the script.
       - This will improve traceability and help differentiate between user-supplied and system-detected SNs.

    2) **Performance Enhancements:**
       - **Multithreading/Parallel Processing:**
         - Implement parallel processing techniques to speed up the file enumeration process, especially for large drives.
         - Utilize PowerShell's `ForEach-Object -Parallel` or background jobs to handle multiple directories simultaneously.
       - **Progress Indicators:**
         - Add progress bars or status updates to inform users about the current state of the scanning process.
         - This improves user experience by providing real-time feedback during lengthy operations.

    3) **Unicode Character Handling:**
       - **Priority Improvement:**
         - Ensure that the script correctly handles file and directory names containing Unicode characters.
         - This involves verifying that all file operations and CSV exports maintain proper encoding to prevent data corruption or loss.
         - Address any issues related to displaying, processing, or exporting Unicode characters to ensure accurate and reliable results.

    4) **Log files into folders**

#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the drive letter to catalog (e.g., 'N').")]
    [ValidatePattern("^[A-Za-z]$")]
    [string]$DriveLetter,

    [Parameter(Mandatory = $false, HelpMessage = "Enter the serial number of the drive. If not provided, it will be auto-detected.")]
    [ValidatePattern("^[A-Za-z0-9\-]+$")]  # Adjust the pattern based on your SN format
    [string]$SerialNumber
)

# Function to format size in TB with two decimal places
function Convert-ToTB {
    param (
        [double]$SizeInBytes
    )
    return "{0:N2}" -f ($SizeInBytes / 1TB)
}

# Function to sanitize file names by replacing invalid characters
function Sanitize-FileName {
    param (
        [string]$InputString
    )
    return ($InputString -replace '[\\/:*?"<>|]', '_').Trim()
}

# Function to determine if a drive is SSD based on MediaType and Model
function Determine-IsSSD {
    param (
        [string]$MediaType,
        [string]$Model
    )
    
    # Define patterns that are indicative of SSDs
    $ssdPatterns = @(
        "SSD",
        "WDS", # Example: Western Digital SSDs often contain 'WDS'
        "NVMe",
        "M.2",
        "SATA SSD",
        "PCIe",
        "Samsung",
        "EVO",
        "PRO",
        "Crucial",
        "MX",
        "Barracuda SSD",
        "Kingston",
        "SanDisk"
        # Add more patterns as needed
    )
    
    foreach ($pattern in $ssdPatterns) {
        if ($Model -match $pattern) {
            return $true
        }
    }
    
    # Fallback to MediaType if no pattern matches
    if ($MediaType -match "SSD") {
        return $true
    }
    
    return $false
}

# Function to log messages to a separate log file
function Log-Message {
    param (
        [string]$Message,
        [string]$LogFilePath,
        [string]$Level = "INFO"  # Default level is INFO
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Level - $Message" | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
}

# Construct the drive path
$drivePath = "$DriveLetter`:"

# Define initial log file path (will be updated after gathering metadata)
$initialLogFile = "CatalogDrive_Errors.log"

# Initialize or clear the initial log file
try {
    if (Test-Path $initialLogFile) {
        Clear-Content -Path $initialLogFile
    } else {
        New-Item -Path $initialLogFile -ItemType File -Force | Out-Null
    }
}
catch {
    Write-Host "Failed to initialize log file: $_" -ForegroundColor Red
    exit 1
}

# Check if the drive exists
if (-not (Test-Path $drivePath)) {
    Write-Host "Drive $drivePath does not exist. Please check the input and try again." -ForegroundColor Red
    Log-Message "Drive $drivePath does not exist." $initialLogFile "ERROR"
    exit 1
}

# Retrieve logical disk information using Get-CimInstance
$logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$drivePath'" 

if (-not $logicalDisk) {
    Write-Host "Failed to retrieve logical disk information for $drivePath." -ForegroundColor Yellow
    Log-Message "Failed to retrieve logical disk information for $drivePath." $initialLogFile "ERROR"
    exit 1
}

# Retrieve partition associated with the logical disk
$partition = Get-CimInstance -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$drivePath'} WHERE AssocClass = Win32_LogicalDiskToPartition" 

if (-not $partition) {
    Write-Host "Failed to retrieve partition information for $drivePath." -ForegroundColor Yellow
    Log-Message "Failed to retrieve partition information for $drivePath." $initialLogFile "ERROR"
    exit 1
}

# Retrieve physical disk associated with the partition
$physicalDrive = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" 

if (-not $physicalDrive) {
    Write-Host "Failed to retrieve physical drive information for $drivePath." -ForegroundColor Yellow
    Log-Message "Failed to retrieve physical drive information for $drivePath." $initialLogFile "ERROR"
    exit 1
}

# Extract necessary metadata
$mediaType = $physicalDrive.MediaType
$model = $physicalDrive.Model
$interfaceType = $physicalDrive.InterfaceType

# Determine Serial Number
if ($PSBoundParameters.ContainsKey('SerialNumber')) {
    $serialNumber = $SerialNumber.Trim()
    if ([string]::IsNullOrEmpty($serialNumber)) {
        Write-Host "Provided SerialNumber is empty. Using auto-detected SerialNumber." -ForegroundColor Yellow
        Log-Message "Provided SerialNumber is empty. Using auto-detected SerialNumber." $initialLogFile "WARNING"
        $serialNumber = $physicalDrive.SerialNumber.Trim()
        if ([string]::IsNullOrEmpty($serialNumber)) {
            $serialNumber = "UnknownSN"
        }
    }
} else {
    $serialNumber = $physicalDrive.SerialNumber.Trim()
    if ([string]::IsNullOrEmpty($serialNumber)) {
        $serialNumber = "UnknownSN"
    }
}

# Determine if the drive is SSD
$isSSD = Determine-IsSSD -MediaType $mediaType -Model $model

# Calculate drive size in TB
$totalSizeTB = Convert-ToTB -SizeInBytes $logicalDisk.Size

# Calculate free space in TB
$freeSpaceTB = "{0:N2}" -f ($logicalDisk.FreeSpace / 1TB)

# Determine SSD or HDD based on $isSSD
$driveType = if ($isSSD) { "SSD" } else { "HDD" }

# Generate output file names based on Serial Number, Drive Type, and Size
$sanitizedSerial = Sanitize-FileName -InputString $serialNumber
# Use integer TB value if possible
$sizeTBInt = [math]::Round([double]$totalSizeTB)
$outputBaseName = "${sanitizedSerial}_${driveType}_${sizeTBInt}TB"

# Update log file path to include the base name
$logFile = "${outputBaseName}_CatalogDrive_Errors.log"

# Initialize or clear the updated log file
try {
    if (Test-Path $logFile) {
        Clear-Content -Path $logFile
    } else {
        New-Item -Path $logFile -ItemType File -Force | Out-Null
    }
}
catch {
    Write-Host "Failed to initialize log file: $_" -ForegroundColor Red
    exit 1
}

# Define output file paths with pipe delimiter to minimize parsing issues
$driveMetadataFile = "${outputBaseName}_DriveMetadata.csv"
$fileDetailsFile  = "${outputBaseName}_FileDetails.csv"

# Create a PSObject for drive metadata
$driveMetadata = [PSCustomObject]@{
    MediaType      = $mediaType
    SerialNumber   = $serialNumber
    Model          = $model
    InterfaceType  = $interfaceType
    IsSSD          = $isSSD
    TotalSizeTB    = $totalSizeTB
    FreeSpaceTB    = $freeSpaceTB
    FileSystem     = $logicalDisk.FileSystem
    VolumeName     = $logicalDisk.VolumeName
    DriveLetter    = $logicalDisk.DeviceID
    LastBootUpTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime.ToString() -replace '\..*',''
}

# Export Drive Metadata to CSV with pipe delimiter
try {
    $driveMetadata | Export-Csv -Path $driveMetadataFile -NoTypeInformation -Encoding UTF8 -Delimiter '|'
    Write-Host "Drive metadata exported to $driveMetadataFile." -ForegroundColor Green
    Log-Message "Drive metadata exported to $driveMetadataFile." $logFile "INFO"
}
catch {
    Write-Host "Failed to export drive metadata: $_" -ForegroundColor Red
    Log-Message "Failed to export drive metadata: $_" $logFile "ERROR"
}

# Collect file details
Write-Host "Scanning files in $drivePath. This may take a while depending on the size of the drive..." -ForegroundColor Cyan
Log-Message "Started scanning files in $drivePath." $logFile "INFO"

# Initialize the FileDetails CSV with headers using pipe delimiter
try {
    "FullName|Length|LastWriteTime|CreationTime|Status" | Out-File -FilePath $fileDetailsFile -Encoding UTF8
}
catch {
    Write-Host "Failed to initialize FileDetails CSV: $_" -ForegroundColor Red
    Log-Message "Failed to initialize FileDetails CSV: $_" $logFile "ERROR"
    exit 1
}

# Function to recursively get files and handle access denied errors
function Get-AccessibleFiles {
    param (
        [string]$Path
    )
    
    # Define directories to exclude (optional)
    $excludedDirs = @("System Volume Information", "Recycler", "$RECYCLE.BIN")
    
    try {
        # Get all items in the current directory
        $items = Get-ChildItem -Path $Path -Force -ErrorAction Stop
    }
    catch {
        # Log the error and add to FileDetails with Status
        $errorMessage = $_.Exception.Message
        $status = "Access Denied or Error: $errorMessage"
        "$Path| | | |$status" | Out-File -FilePath $fileDetailsFile -Append -Encoding UTF8
        Log-Message "Access denied or error accessing path '$Path'. Error: $errorMessage" $logFile "ERROR"
        return
    }

    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            # Check if the directory is excluded
            if ($excludedDirs -contains $item.Name) {
                # Add excluded directory to FileDetails with Status
                "$($item.FullName)| | | |Excluded Directory" | Out-File -FilePath $fileDetailsFile -Append -Encoding UTF8
                Log-Message "Excluded directory '$($item.FullName)' skipped." $logFile "INFO"
                continue
            }
            
            # Recursively search within subdirectories
            Get-AccessibleFiles -Path $item.FullName
        }
        else {
            # Collect file details without Name and Extension for efficiency
            $fileDetail = "$($item.FullName)|$($item.Length)|$($item.LastWriteTime)|$($item.CreationTime)|"
            # Add the file detail to the FileDetails CSV
            $fileDetail | Out-File -FilePath $fileDetailsFile -Append -Encoding UTF8
        }
    }
}

# Start the recursive file collection
Get-AccessibleFiles -Path $drivePath

Write-Host "File details exported to $fileDetailsFile." -ForegroundColor Green
Log-Message "File details exported to $fileDetailsFile." $logFile "INFO"

Write-Host "Cataloging complete. Check '$logFile' for any errors encountered during the process." -ForegroundColor Green
Log-Message "Cataloging completed successfully." $logFile "INFO"