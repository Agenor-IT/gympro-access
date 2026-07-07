$ErrorActionPreference = "Stop"

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $baseDir "config.json"

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "No se encontro config.json en $baseDir"
}

$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$hostName = if ($config.Host) { [string]$config.Host } else { "127.0.0.1" }
$port = if ($config.Port) { [int]$config.Port } else { 8787 }
$executablePath = if ($config.ExecutablePath) { [string]$config.ExecutablePath } else { "C:\TangoAccess\abrir.exe" }
$executableDir = Split-Path -Parent $executablePath
$workingDirectory = if ($config.WorkingDirectory) { [string]$config.WorkingDirectory } elseif ($executableDir) { $executableDir } else { $baseDir }
$windowStyle = if ($config.WindowStyle) { [string]$config.WindowStyle } else { "Normal" }
$requireToken = if ($null -ne $config.RequireToken) { [bool]$config.RequireToken } else { $true }
$token = if ($config.Token) { [string]$config.Token } else { "" }
$minIntervalMs = if ($config.MinIntervalMs) { [int]$config.MinIntervalMs } else { 1500 }

$script:lastOpenAt = [DateTimeOffset]::MinValue

function Write-JsonResponse {
    param(
        [Parameter(Mandatory = $true)] $Response,
        [Parameter(Mandatory = $true)] [int] $StatusCode,
        [Parameter(Mandatory = $true)] $Data
    )

    $json = $Data | ConvertTo-Json -Compress -Depth 8
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json; charset=utf-8"
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Set-CorsHeaders {
    param([Parameter(Mandatory = $true)] $Response)

    $Response.Headers["Access-Control-Allow-Origin"] = "*"
    $Response.Headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS"
    $Response.Headers["Access-Control-Allow-Headers"] = "Content-Type,X-GymPro-Gateway-Token"
}

function Test-Token {
    param([Parameter(Mandatory = $true)] $Request)

    if (-not $requireToken) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($token)) {
        return $false
    }

    return $Request.Headers["X-GymPro-Gateway-Token"] -eq $token
}

$prefix = "http://${hostName}:$port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "[GymProAccess] Escuchando en $prefix"
Write-Host "[GymProAccess] Ejecutable: $executablePath"
Write-Host "[GymProAccess] Carpeta de trabajo: $workingDirectory"
Write-Host "[GymProAccess] Ventana: $windowStyle"
Write-Host "[GymProAccess] Token requerido: $requireToken"

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    Set-CorsHeaders -Response $response

    try {
        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 204
            $response.ContentLength64 = 0
            $response.OutputStream.Close()
            continue
        }

        $path = $request.Url.AbsolutePath.TrimEnd("/")
        if ([string]::IsNullOrWhiteSpace($path)) {
            $path = "/"
        }

        if ($request.HttpMethod -eq "GET" -and $path -eq "/health") {
            Write-JsonResponse -Response $response -StatusCode 200 -Data @{
                ok = $true
                executableConfigured = $executablePath
                executableExists = [bool](Test-Path -LiteralPath $executablePath)
                workingDirectory = $workingDirectory
                workingDirectoryExists = [bool](Test-Path -LiteralPath $workingDirectory)
                windowStyle = $windowStyle
                tokenRequired = $requireToken
                tokenConfigured = -not [string]::IsNullOrWhiteSpace($token)
            }
            continue
        }

        if ($request.HttpMethod -eq "POST" -and $path -eq "/open") {
            if (-not (Test-Token -Request $request)) {
                Write-JsonResponse -Response $response -StatusCode 401 -Data @{
                    ok = $false
                    error = "invalid_token"
                }
                continue
            }

            if (-not (Test-Path -LiteralPath $executablePath)) {
                Write-JsonResponse -Response $response -StatusCode 500 -Data @{
                    ok = $false
                    error = "executable_not_found"
                    executablePath = $executablePath
                }
                continue
            }

            if (-not (Test-Path -LiteralPath $workingDirectory)) {
                Write-JsonResponse -Response $response -StatusCode 500 -Data @{
                    ok = $false
                    error = "working_directory_not_found"
                    workingDirectory = $workingDirectory
                }
                continue
            }

            $now = [DateTimeOffset]::UtcNow
            $elapsedMs = ($now - $script:lastOpenAt).TotalMilliseconds
            if ($elapsedMs -lt $minIntervalMs) {
                Write-JsonResponse -Response $response -StatusCode 429 -Data @{
                    ok = $false
                    error = "rate_limited"
                    retryAfterMs = [int]($minIntervalMs - $elapsedMs)
                }
                continue
            }

            $script:lastOpenAt = $now
            $process = Start-Process -FilePath $executablePath -WorkingDirectory $workingDirectory -WindowStyle $windowStyle -PassThru

            Write-JsonResponse -Response $response -StatusCode 200 -Data @{
                ok = $true
                status = "open_command_sent"
                executablePath = $executablePath
                workingDirectory = $workingDirectory
                processId = $process.Id
            }
            continue
        }

        Write-JsonResponse -Response $response -StatusCode 404 -Data @{
            ok = $false
            error = "not_found"
        }
    } catch {
        try {
            Write-JsonResponse -Response $response -StatusCode 500 -Data @{
                ok = $false
                error = "gateway_error"
                message = $_.Exception.Message
            }
        } catch {
        }
    }
}
