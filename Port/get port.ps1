$server = "DESKTOP-APNO79K"
# $ports = 1433, 1434, 4022 + (14330..14340) + (49152..49200)  # Adjust ranges as needed
$ports = 1433..65539

$useWindowsAuth = $true
$username = "yourUsername"
$password = "yourPassword"

foreach ($port in $ports) {
    $connString = if ($useWindowsAuth) {
        "Server=$server,$port;Integrated Security=True;Connection Timeout=2;"
    } else {
        "Server=$server,$port;User ID=$username;Password=$password;Connection Timeout=2;"
    }

    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection $connString
        $conn.Open()
        Write-Host "✅ SQL Server is accepting connections on port $port"
        $conn.Close()
        break  # Remove this line if you want to scan all ports, not stop at the first success
    } catch {
        # Silent fail — do nothing
    }
}
