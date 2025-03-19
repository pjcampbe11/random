#
.SYNOPSIS
    Multi-threaded ICMP scanner for a /24 subnet.
    Uses parallel execution in PowerShell 7+ and falls back to sequential execution in PowerShell 5.x.

.PARAMETER Subnet
    Base subnet (e.g., "192.168.1") for scanning all 256 hosts.

.PARAMETER Timeout
    Ping timeout per host in milliseconds (default: 4000ms / 4s).

.PARAMETER OutputCSV
    Optional. If provided, saves results to a CSV file.

.EXAMPLE
    .\Ping-Slash24-Compatible.ps1 -Subnet "10.0.0"
    # Scans 10.0.0.0/24 with default settings.

.EXAMPLE
    .\Ping-Slash24-Compatible.ps1 -Subnet "10.0.0" -Timeout 2000
    # Scans 10.0.0.0/24 with a 2-second timeout.

.EXAMPLE
    .\Ping-Slash24-Compatible.ps1 -Subnet "10.0.0" -OutputCSV "ActiveHosts.csv"
    # Scans 10.0.0.0/24 and saves results to "ActiveHosts.csv".

#>

param (
    [string]$Subnet = "192.168.1",  # Default subnet if not provided
    [int]$Timeout = 4000,           # Timeout in milliseconds (default: 4s)
    [string]$OutputCSV = ""         # Optional output CSV file
)

# Determine PowerShell version
$PSVersion = $PSVersionTable.PSVersion.Major

# Generate all IP addresses in the /24 range (0-255)
$Addresses = 0..255 | ForEach-Object { "$Subnet.$_" }

Write-Host "Starting scan of $Subnet.0/24 with a timeout of $Timeout ms..."
Write-Host "Detected PowerShell version: $PSVersion"

# Create an array to store active hosts
$ActiveHosts = @()

# PowerShell 7+ supports parallel execution
if ($PSVersion -ge 7) {
    Write-Host "Using multi-threading for improved performance." -ForegroundColor Cyan

    # Multi-threaded execution using PowerShell 7+ (ForEach-Object -Parallel)
    $Results = $Addresses | ForEach-Object -Parallel {
        param ($IP, $Timeout)

        # Perform an ICMP ping using Test-Connection
        $PingResult = Test-Connection -ComputerName $IP -Count 1 -TimeToLive 64 -TimeoutMilliseconds $Timeout -Quiet -ErrorAction SilentlyContinue

        # If the host responds, return it as an object
        if ($PingResult) {
            [PSCustomObject]@{
                "IP Address" = $IP
                "Timestamp"  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }

    } -ArgumentList $_, $Timeout -ThrottleLimit 100  # Uses 100 parallel threads 🚀

    # Filter out null results
    $ActiveHosts = $Results | Where-Object { $_ -ne $null }

} else {
    # Fallback to sequential execution in PowerShell 5.x
    Write-Host "PowerShell 5.x detected. Running sequentially..." -ForegroundColor Yellow

    foreach ($IP in $Addresses) {
        $PingResult = Test-Connection -ComputerName $IP -Count 1 -TimeToLive 64 -TimeoutMilliseconds $Timeout -Quiet -ErrorAction SilentlyContinue
        if ($PingResult) {
            Write-Host "$IP is online!" -ForegroundColor Green
            $ActiveHosts += [PSCustomObject]@{
                "IP Address" = $IP
                "Timestamp"  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    }
}

# Display scan results
Write-Host "`nScan complete. Active hosts found:" -ForegroundColor Green
$ActiveHosts | ForEach-Object { Write-Host $_."IP Address" }

# Export results if a CSV filename was provided
if ($OutputCSV -ne "") {
    $ActiveHosts | Export-Csv -Path $OutputCSV -NoTypeInformation
    Write-Host "`nResults saved to: $OutputCSV" -ForegroundColor Yellow
}

Write-Host "Scan completed successfully!" -ForegroundColor Cyan
