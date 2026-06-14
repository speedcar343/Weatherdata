# --- KONFIGURATION ---
$stationID = "11723" # Salzburg/Flughafen


$configPath = "$PSScriptRoot\config.json"
$config = Get-Content $configPath | ConvertFrom-Json

$server = $config.Server
$database = $config.Database
$user = $config.Username
$password = $config.Password

$connectionString = "Server=$server;Database=$database;User Id=$user;Password=$password;TrustServerCertificate=True;Encrypt=false;"
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)


$apiUrl = "https://dataset.api.hub.geosphere.at/v1/station/historical/klima-v1-1h"

# Zeitbereich: Letzte 2 Stunden abfragen
$start = (Get-Date).AddHours(-2).ToString("yyyy-MM-ddTHH:mm")
$end = (Get-Date).ToString("yyyy-MM-ddTHH:mm")

# --- API ABFRAGE ---
$fullUrl = "$apiUrl?parameters=TL&station_ids=$stationID&start=$start&end=$end&output_format=json"

try {
    $response = Invoke-RestMethod -Uri $fullUrl -Method Get
    
    # Zugriff auf die Datenstruktur (Die API liefert ein komplexes JSON)
    # TL = Temperatur Luft
    $feature = $response.features[0]
    $ortName = $feature.properties.station_name
    
    # Wir nehmen den aktuellsten Wert aus der Zeitreihe
    $temp = $feature.properties.parameters.TL.data[-1]
    $zeit = $feature.properties.parameters.TL.dates[-1]

    Write-Host "Daten für $ortName abgerufen: $temp °C um $zeit"

    # --- SQL SPEICHERUNG ---
    $conn = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $conn.Open()

    $query = "INSERT INTO Wetterdaten (Ort, Temperatur, Messzeit) VALUES (@ort, @temp, @zeit)"
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $query
    $cmd.Parameters.AddWithValue("@ort", $ortName)
    $cmd.Parameters.AddWithValue("@temp", $temp)
    $cmd.Parameters.AddWithValue("@zeit", $zeit)

    $cmd.ExecuteNonQuery() | Out-Null
    $conn.Close()
    
    Write-Host "Erfolgreich in DB geschrieben."
}
catch {
    Write-Error "Fehler bei der Verarbeitung: $($_.Exception.Message)"
}
