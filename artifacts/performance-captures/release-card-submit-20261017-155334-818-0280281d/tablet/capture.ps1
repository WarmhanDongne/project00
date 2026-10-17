param([Parameter(Mandatory=$true)][string]$DeviceSerial)
$ErrorActionPreference = 'Stop'
$captureDir = 'C:/workspace/git/project00/artifacts/performance-captures/release-card-submit-20261017-155334-818-0280281d/tablet'
$adb = 'C:/Users/USER/AppData/Local/Android/sdk/platform-tools/adb.exe'
$statusPath = Join-Path $captureDir 'capture-status.json'
$stopPath = Join-Path $captureDir 'stop.request'
$started = [DateTimeOffset]::UtcNow
$clock = [Diagnostics.Stopwatch]::StartNew()
$process = $null
$writer = $null
$readCount = 0
$retained = 0
$timingCount = 0
$lastEvent = $null
$categories = @{}
$reason = 'duration_limit'
$meta = Get-Content -LiteralPath (Join-Path $captureDir 'tablet-metadata.json') -Raw | ConvertFrom-Json
function Save-CaptureStatus([string]$state) {
    $value = [ordered]@{
        role='tablet'; state=$state; collectorPid=$PID
        logcatPid=if($null -ne $process){$process.Id}else{$null}
        startedAtUtc=$started.ToString('o')
        updatedAtUtc=[DateTimeOffset]::UtcNow.ToString('o')
        durationSeconds=[Math]::Round($clock.Elapsed.TotalSeconds,1)
        readLines=$readCount; retainedEvents=$retained; structuredTimingEvents=$timingCount
        lastEventEpoch=$lastEvent; categories=$categories; stopReason=$reason
        maxDurationSeconds=1800; maxRetainedEvents=30000
        privacy='App Linux UID only. No raw messages, identifiers, payloads, URLs, tokens or account data stored.'
    }
    $temporary = Join-Path $captureDir 'capture-status.tmp'
    $value | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporary -Encoding utf8
    Move-Item -LiteralPath $temporary -Destination $statusPath -Force
}
try {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $adb
    foreach($argument in @('-s',$DeviceSerial,'logcat','-b','main','-b','crash',"--uid=$($meta.appLinuxUid)",'-v','epoch','-T','1')) {
        $info.ArgumentList.Add($argument)
    }
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($info)
    $errorTask = $process.StandardError.ReadToEndAsync()
    $writer = [IO.StreamWriter]::new((Join-Path $captureDir 'tablet-events.sanitized.jsonl'),$true,[Text.UTF8Encoding]::new($false))
    $writer.AutoFlush = $true
    $writer.WriteLine(([ordered]@{kind='capture_started';role='tablet';hostUtc=$started.ToString('o');format='logcat epoch';rawMessagesStored=$false} | ConvertTo-Json -Compress))
    $nextStatus = 0
    $readTask = $process.StandardOutput.ReadLineAsync()
    while($clock.Elapsed.TotalSeconds -lt 1800 -and $retained -lt 30000) {
        if(Test-Path -LiteralPath $stopPath){$reason='requested';break}
        if($clock.Elapsed.TotalSeconds -ge $nextStatus){
            $reason='collecting';Save-CaptureStatus 'running';$nextStatus=$clock.Elapsed.TotalSeconds+5
        }
        if(-not $readTask.Wait(500)){
            if($process.HasExited){$reason='logcat_exited';break}
            continue
        }
        $line = $readTask.GetAwaiter().GetResult()
        if($null -eq $line){$reason='logcat_eof';break}
        $readTask = $process.StandardOutput.ReadLineAsync()
        $readCount++
        if($line -notmatch '^\s*(?<timestamp>\d{9,}\.\d+)\s+(?<pid>\d+)\s+(?<tid>\d+)\s+(?<priority>[VDIWEF])\s+(?<tag>.*?)\s*:\s?(?<message>.*)$'){continue}
        $timestamp = [double]::Parse($Matches.timestamp,[Globalization.CultureInfo]::InvariantCulture)
        if($timestamp -lt ($started.ToUnixTimeMilliseconds()/1000.0)-1){continue}
        $priority = $Matches.priority
        $rawTag = $Matches.tag.Trim()
        $message = $Matches.message
        $tag = 'other'
        foreach($known in @('flutter','FirebaseAuth','FirebaseAppCheck','FirebaseCrashlytics','FirebaseDatabase','FirebaseFunctions','AndroidRuntime','Choreographer','OpenGLRenderer','ProfileInstaller','ViewRootImpl','InputMethodManager','SurfaceView','InputTransport','BufferQueueProducer','DynamiteModule','System.err')){
            if($rawTag -eq $known -or $rawTag.StartsWith($known+'@')){$tag=$known;break}
        }
        $event = [ordered]@{kind='app_log';role='tablet';deviceEpochSeconds=$timestamp;priority=$priority;tag=$tag;category='metadata_only'}
        if($message -match 'Skipped\s+(\d+)\s+frames'){$event.category='render_skipped_frames';$event.frameCount=[int]$Matches[1]}
        elseif($message -match 'Davey!.*duration=(\d+)ms'){$event.category='render_slow_frame';$event.durationMs=[int]$Matches[1]}
        elseif($message -match 'ViewPostIme pointer ([01])'){$event.category='input_pointer_'+$Matches[1]}
        elseif($message -match 'FATAL EXCEPTION|Fatal signal'){$event.category='fatal_error'}
        elseif($message -match 'PERMISSION_DENIED|permission-denied'){$event.category='permission_denied'}
        elseif($message -match 'UNAUTHENTICATED|unauthenticated'){$event.category='unauthenticated'}
        elseif($message -match 'DEADLINE_EXCEEDED|deadline-exceeded|timed out|TimeoutException'){$event.category='timeout'}
        elseif($message -match 'UnknownHostException|Unable to resolve host|NETWORK_ERROR|network error|UNAVAILABLE'){$event.category='network_error'}
        elseif($message -match '\[game_comm\]'){$event.category='game_communication_marker'}
        elseif($message -match '\[room_connection\]'){$event.category='room_connection_marker'}
        elseif($tag -eq 'FirebaseAppCheck' -or $message -match 'AppCheck|App Check|Play Integrity'){$event.category='app_check_event'}
        if($message -match 'operation=(room_create_timing|room_close_timing|createRealtimeRoom|removeRealtimeRoomPlayer|closeRoom|joinRealtimeRoom|validateRealtimeRoom|fetchRealtimeRoomSession|recovery)\b'){$event.operation=$Matches[1]}
        if($message -match '\btotal_ms=(\d+)\b'){$event.totalMs=[int64]$Matches[1];$timingCount++}
        if($message -match '\belapsed_ms=(\d+)\b'){$event.elapsedMs=[int64]$Matches[1]}
        if($message -match '\bstatus=(success|failure|started|accepted|applied|stale|notApplied)\b'){$event.outcome=$Matches[1]}
        $writer.WriteLine(($event | ConvertTo-Json -Compress -Depth 4))
        $retained++
        $lastEvent=$timestamp
        if(-not $categories.ContainsKey($event.category)){$categories[$event.category]=0}
        $categories[$event.category]++
    }
    if($clock.Elapsed.TotalSeconds -ge 1800){$reason='duration_limit'}
    if($retained -ge 30000){$reason='event_limit'}
    if($reason -eq 'collecting'){$reason='completed'}
    Save-CaptureStatus 'stopped'
}
catch {
    $reason='collector_error'
    Save-CaptureStatus 'failed'
    exit 1
}
finally {
    if($null -ne $process -and -not $process.HasExited){$process.Kill();$process.WaitForExit(5000) | Out-Null}
    if($null -ne $writer){
        $writer.WriteLine(([ordered]@{kind='capture_stopped';role='tablet';hostUtc=[DateTimeOffset]::UtcNow.ToString('o');reason=$reason} | ConvertTo-Json -Compress))
        $writer.Dispose()
    }
    if($null -ne $process){$process.Dispose()}
}



