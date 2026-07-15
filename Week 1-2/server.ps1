# Aether Chatbot REST API Server
# Runs on Port 3000. Loads FAQ knowledge base from faq.json at startup.

$port = 3000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")

try {
    $listener.Start()
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " Aether Chatbot REST API running on http://localhost:$port" -ForegroundColor Green
    Write-Host " Press Ctrl+C to stop." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
} catch {
    Write-Error "Failed to start. Port $port may already be in use."
    Exit
}

# Load FAQ from external JSON file
$faqPath = Join-Path $PSScriptRoot "faq.json"
$faqEntries = Get-Content -Path $faqPath -Encoding UTF8 -Raw | ConvertFrom-Json

# In-memory chat history
$chatHistory = New-Object System.Collections.ArrayList

# Match user input against FAQ keywords using word-boundary regex
function Get-BotResponse($userInput) {
    $inputLower = $userInput.ToLower().Trim()
    foreach ($entry in $faqEntries) {
        foreach ($kw in $entry.keywords) {
            # Use regex word boundary so 'hi' doesn't match inside 'machine'
            $escaped = [regex]::Escape($kw)
            if ($inputLower -match "(^|\s|[^a-z])$escaped([^a-z]|\s|$)") {
                return $entry.answer
            }
        }
    }
    return "I'm not sure I have a specific answer for that yet!`n`nTry asking about:`n- Programming (JavaScript, Python, Node.js, REST APIs)`n- Web development (HTML, CSS, databases)`n- Tech concepts (AI/ML, Docker, Git, security)`n- Writing (emails)`n- Brainstorming ideas`n`nType 'help' to see all available topics."
}

# Send a JSON HTTP response
function Send-JsonResponse($response, $statusCode, $dataObj) {
    $json   = ConvertTo-Json $dataObj -Depth 10
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $response.StatusCode      = $statusCode
    $response.ContentType     = "application/json; charset=utf-8"
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()
}

# Send a static file as an HTTP response
function Send-FileResponse($response, $filePath, $contentType) {
    if ((Test-Path $filePath) -and -not (Test-Path $filePath -PathType Container)) {
        $buffer = [System.IO.File]::ReadAllBytes($filePath)
        $response.StatusCode      = 200
        $response.ContentType     = $contentType
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    } else {
        $response.StatusCode = 404
        $nb = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
        $response.OutputStream.Write($nb, 0, $nb.Length)
    }
    $response.Close()
}

# Main request loop
while ($listener.IsListening) {
    try {
        $context  = $listener.GetContext()
        $request  = $context.Request
        $response = $context.Response
        $path     = $request.Url.AbsolutePath
        $method   = $request.HttpMethod

        $response.Headers.Add("Access-Control-Allow-Origin",  "*")
        $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

        if ($method -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }

        Write-Host "[$((Get-Date).ToString("HH:mm:ss"))] $method $path" -ForegroundColor Gray

        if ($path -eq "/api/history" -and $method -eq "GET") {
            Send-JsonResponse -response $response -statusCode 200 -dataObj $chatHistory

        } elseif ($path -eq "/api/history" -and $method -eq "DELETE") {
            $chatHistory.Clear()
            Send-JsonResponse -response $response -statusCode 200 -dataObj @{ message = "Chat history cleared." }

        } elseif ($path -eq "/api/chat" -and $method -eq "POST") {
            $reader   = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $bodyText = $reader.ReadToEnd()
            $body     = ConvertFrom-Json $bodyText

            if (-not $body.message) {
                Send-JsonResponse -response $response -statusCode 400 -dataObj @{ error = "Message is required." }
                continue
            }

            $timestamp = (Get-Date).ToString("hh:mm tt")
            $botText   = Get-BotResponse $body.message

            $userMsg = [PSCustomObject]@{ sender = "user"; text = $body.message; timestamp = $timestamp }
            $botMsg  = [PSCustomObject]@{ sender = "bot";  text = $botText;      timestamp = $timestamp }

            [void]$chatHistory.Add($userMsg)
            [void]$chatHistory.Add($botMsg)

            Send-JsonResponse -response $response -statusCode 200 -dataObj $botMsg

        } else {
            $publicPath    = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "public"))
            $fileRequested = if ($path -eq "/") { "/index.html" } else { $path }
            $fullPath      = Join-Path $publicPath $fileRequested
            $resolvedPath  = [System.IO.Path]::GetFullPath($fullPath)

            # Prevent directory traversal attacks
            if (-not $resolvedPath.StartsWith($publicPath)) {
                $response.StatusCode = 403
                $eb = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
                $response.OutputStream.Write($eb, 0, $eb.Length)
                $response.Close()
                continue
            }

            $contentType = switch -Wildcard ($resolvedPath) {
                "*.html" { "text/html; charset=utf-8" }
                "*.css"  { "text/css" }
                "*.js"   { "application/javascript" }
                "*.json" { "application/json" }
                "*.png"  { "image/png" }
                "*.jpg"  { "image/jpeg" }
                default  { "text/plain" }
            }

            Send-FileResponse -response $response -filePath $resolvedPath -contentType $contentType
        }
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        try {
            $response.StatusCode = 500
            $eb = [System.Text.Encoding]::UTF8.GetBytes("Internal Server Error")
            $response.OutputStream.Write($eb, 0, $eb.Length)
            $response.Close()
        } catch {}
    }
}
