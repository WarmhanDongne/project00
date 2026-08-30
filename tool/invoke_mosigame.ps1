Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$guardStartedAt = [DateTime]::UtcNow
$guardStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$guardArguments = @($args | ForEach-Object { [string]$_ })
$guardJson = $guardArguments -contains '--json'

function Write-GuardError {
    param([Parameter(Mandatory = $true)][string]$Message)
    [Console]::Error.WriteLine("[mosigame guard] $Message")
}

function Write-GuardJsonFailure {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$GuardStatus,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][string]$Reason,
        [Parameter(Mandatory = $true)][bool]$CleanupConfirmed,
        [Parameter(Mandatory = $true)][bool]$ProgressObserved
    )

    $targetCommand = $guardArguments |
        Where-Object { -not $_.StartsWith('-') } |
        Select-Object -First 1
    $result = [ordered]@{
        schemaVersion = 1
        resultType = 'invocationGuard'
        command = $targetCommand
        status = $Status
        startedAt = $guardStartedAt.ToString('o')
        durationMs = [int64]$guardStopwatch.ElapsedMilliseconds
        exitCode = $ExitCode
        guard = [ordered]@{
            status = $GuardStatus
            reason = $Reason
            progressObserved = $ProgressObserved
            cleanupConfirmed = $CleanupConfirmed
        }
    }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 4))
}

function Complete-GuardFailure {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$GuardStatus,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][string]$Reason,
        [Parameter(Mandatory = $true)][string]$Message,
        [bool]$CleanupConfirmed = $true,
        [bool]$ProgressObserved = $false
    )

    Write-GuardError $Message
    if ($guardJson) {
        Write-GuardJsonFailure -Status $Status -GuardStatus $GuardStatus `
            -ExitCode $ExitCode -Reason $Reason `
            -CleanupConfirmed $CleanupConfirmed `
            -ProgressObserved $ProgressObserved
    }
    exit $ExitCode
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    Complete-GuardFailure -Status 'BLOCKED' -GuardStatus 'BLOCKED' -ExitCode 3 `
        -Reason 'unsupported-platform' `
        -Message 'This invocation guard currently supports Windows only.'
}

if ($guardArguments.Count -eq 0) {
    Complete-GuardFailure -Status 'INVALID' -GuardStatus 'INVALID' -ExitCode 2 `
        -Reason 'missing-command' `
        -Message 'A Project CLI command is required.'
}

$guardRepositoryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $PSScriptRoot -ChildPath '..')
)
$guardRequiredPaths = @(
    (Join-Path $guardRepositoryRoot 'pubspec.yaml'),
    (Join-Path $guardRepositoryRoot 'bin\mosigame.dart')
)
if ($guardRequiredPaths.Where({ -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count -gt 0) {
    Complete-GuardFailure -Status 'BLOCKED' -GuardStatus 'BLOCKED' -ExitCode 3 `
        -Reason 'repository-root-not-found' `
        -Message 'The repository root could not be verified from the guard location.'
}

function Read-PositiveIntOverride {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$DefaultValue
    )

    $rawValue = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($rawValue)) {
        return $DefaultValue
    }
    $parsedValue = 0
    if (-not [int]::TryParse($rawValue, [ref]$parsedValue) -or $parsedValue -le 0) {
        throw "The test-only override $Name must be a positive integer."
    }
    return $parsedValue
}

function Read-NonNegativeIntOverride {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$DefaultValue
    )

    $rawValue = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($rawValue)) {
        return $DefaultValue
    }
    $parsedValue = 0
    if (-not [int]::TryParse($rawValue, [ref]$parsedValue) -or $parsedValue -lt 0) {
        throw "The test-only override $Name must be a non-negative integer."
    }
    return $parsedValue
}

try {
    # Millisecond overrides are intentionally environment-only and exist so the
    # fake-child contract tests do not alter the production defaults.
    $guardStartupTimeoutMs = Read-PositiveIntOverride `
        -Name 'MOSIGAME_GUARD_TEST_STARTUP_TIMEOUT_MS' -DefaultValue 60000
    $guardOverallTimeoutMs = Read-PositiveIntOverride `
        -Name 'MOSIGAME_GUARD_TEST_OVERALL_TIMEOUT_MS' -DefaultValue 900000
    $guardHeartbeatMs = Read-PositiveIntOverride `
        -Name 'MOSIGAME_GUARD_TEST_HEARTBEAT_MS' -DefaultValue 30000
    $guardTerminationGraceMs = Read-PositiveIntOverride `
        -Name 'MOSIGAME_GUARD_TEST_TERMINATION_GRACE_MS' -DefaultValue 5000
    $guardSetupDelayMs = Read-NonNegativeIntOverride `
        -Name 'MOSIGAME_GUARD_TEST_SETUP_DELAY_MS' -DefaultValue 0
} catch {
    Complete-GuardFailure -Status 'FAIL' -GuardStatus 'INTERNAL_ERROR' -ExitCode 4 `
        -Reason 'invalid-guard-configuration' -Message $_.Exception.Message
}

$guardTargetOverride = [Environment]::GetEnvironmentVariable(
    'MOSIGAME_GUARD_TEST_EXECUTABLE'
)
if ([string]::IsNullOrWhiteSpace($guardTargetOverride)) {
    $guardDartCommand = Get-Command 'dart.bat' -CommandType Application `
        -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $guardDartCommand) {
        Complete-GuardFailure -Status 'BLOCKED' -GuardStatus 'BLOCKED' -ExitCode 3 `
            -Reason 'dart-launcher-not-found' `
            -Message 'dart.bat was not found on PATH.'
    }
    $guardTargetExecutable = $guardDartCommand.Source
    $guardTargetArguments = @('run', ':mosigame')
} else {
    $guardTargetExecutable = [System.IO.Path]::GetFullPath($guardTargetOverride)
    $guardTargetArguments = @()
}

if (-not (Test-Path -LiteralPath $guardTargetExecutable -PathType Leaf)) {
    Complete-GuardFailure -Status 'BLOCKED' -GuardStatus 'BLOCKED' -ExitCode 3 `
        -Reason 'launcher-not-found' `
        -Message 'The guarded launcher does not exist.'
}

$guardBridge = @'
$ErrorActionPreference = 'Stop'
$payloadBytes = [Convert]::FromBase64String($env:MOSIGAME_GUARD_PAYLOAD)
$payloadJson = [Text.Encoding]::UTF8.GetString($payloadBytes)
$payload = $payloadJson | ConvertFrom-Json
$target = [string]$payload.executable
$targetArguments = @($payload.arguments | ForEach-Object { [string]$_ })
Set-Location -LiteralPath ([string]$payload.workingDirectory)
& $target @targetArguments
if ($null -eq $LASTEXITCODE) { exit 0 }
exit $LASTEXITCODE
'@

$guardPayload = [ordered]@{
    executable = $guardTargetExecutable
    arguments = $guardTargetArguments
    workingDirectory = $guardRepositoryRoot
} | ConvertTo-Json -Compress -Depth 3
$guardPayloadBytes = [Text.Encoding]::UTF8.GetBytes($guardPayload)
$guardPayloadBase64 = [Convert]::ToBase64String($guardPayloadBytes)
$guardCliArgumentsJson = ConvertTo-Json -InputObject @($guardArguments) `
    -Compress -Depth 2
$guardCliArgumentsBase64 = [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes($guardCliArgumentsJson)
)
$guardStartupMarker = Join-Path ([IO.Path]::GetTempPath()) (
    'mosigame-guard-startup-{0}.marker' -f ([Guid]::NewGuid().ToString('D'))
)
$guardBridgeBase64 = [Convert]::ToBase64String(
    [Text.Encoding]::Unicode.GetBytes($guardBridge)
)

$guardNativeSource = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;

public sealed class MosigameGuardResult
{
    public int ExitCode;
    public string Kind;
    public string Reason;
    public bool CleanupConfirmed;
    public bool ProgressObserved;
    public long FirstProgressMs;
}

public static class MosigameWindowsInvocationGuard
{
    private const uint CREATE_SUSPENDED = 0x00000004;
    private const uint STARTF_USESTDHANDLES = 0x00000100;
    private const uint HANDLE_FLAG_INHERIT = 0x00000001;
    private const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;
    private const int JobObjectBasicAccountingInformation = 1;
    private const int JobObjectExtendedLimitInformation = 9;
    private const uint WAIT_OBJECT_0 = 0;
    private const uint WAIT_TIMEOUT = 258;
    private const int STD_INPUT_HANDLE = -10;

    [StructLayout(LayoutKind.Sequential)]
    private struct SECURITY_ATTRIBUTES
    {
        public int nLength;
        public IntPtr lpSecurityDescriptor;
        public bool bInheritHandle;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct STARTUPINFO
    {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PROCESS_INFORMATION
    {
        public IntPtr hProcess;
        public IntPtr hThread;
        public uint dwProcessId;
        public uint dwThreadId;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_BASIC_LIMIT_INFORMATION
    {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IO_COUNTERS
    {
        public ulong ReadOperationCount;
        public ulong WriteOperationCount;
        public ulong OtherOperationCount;
        public ulong ReadTransferCount;
        public ulong WriteTransferCount;
        public ulong OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
    {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_BASIC_ACCOUNTING_INFORMATION
    {
        public long TotalUserTime;
        public long TotalKernelTime;
        public long ThisPeriodTotalUserTime;
        public long ThisPeriodTotalKernelTime;
        public uint TotalPageFaultCount;
        public uint TotalProcesses;
        public uint ActiveProcesses;
        public uint TotalTerminatedProcesses;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateJobObject(IntPtr attributes, string name);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetInformationJobObject(
        IntPtr job,
        int infoClass,
        IntPtr info,
        uint length);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool QueryInformationJobObject(
        IntPtr job,
        int infoClass,
        out JOBOBJECT_BASIC_ACCOUNTING_INFORMATION info,
        uint length,
        IntPtr returnLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateJobObject(IntPtr job, uint exitCode);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcess(
        string applicationName,
        StringBuilder commandLine,
        IntPtr processAttributes,
        IntPtr threadAttributes,
        bool inheritHandles,
        uint creationFlags,
        IntPtr environment,
        string currentDirectory,
        ref STARTUPINFO startupInfo,
        out PROCESS_INFORMATION processInformation);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CreatePipe(
        out IntPtr readPipe,
        out IntPtr writePipe,
        ref SECURITY_ATTRIBUTES attributes,
        uint size);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetHandleInformation(IntPtr handle, uint mask, uint flags);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint ResumeThread(IntPtr thread);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(IntPtr process, uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    private sealed class OutputState
    {
        public int ProgressObserved;
        public long FirstProgressMs = -1;
        public readonly object Sync = new object();
        public readonly MemoryStream JsonStdout = new MemoryStream();
    }

    public static MosigameGuardResult Run(
        string powerShellPath,
        string encodedBridge,
        string workingDirectory,
        bool jsonMode,
        string startupMarkerPath,
        long initialElapsedMs,
        int startupTimeoutMs,
        int overallTimeoutMs,
        int heartbeatMs,
        int terminationGraceMs,
        bool forceCleanupFailure,
        bool forceJobAssignmentFailure,
        bool forceAssignmentCleanupFailure,
        int setupDelayMs,
        int simulatedInterruptMs)
    {
        MosigameGuardResult result = new MosigameGuardResult();
        result.ExitCode = 4;
        result.Kind = "internal-error";
        result.Reason = "guard-internal-error";
        result.CleanupConfirmed = false;

        IntPtr job = IntPtr.Zero;
        IntPtr stdoutRead = IntPtr.Zero;
        IntPtr stdoutWrite = IntPtr.Zero;
        IntPtr stderrRead = IntPtr.Zero;
        IntPtr stderrWrite = IntPtr.Zero;
        PROCESS_INFORMATION processInfo = new PROCESS_INFORMATION();
        OutputState output = new OutputState();
        Stopwatch stopwatch = Stopwatch.StartNew();
        int cancelRequested = 0;
        ConsoleCancelEventHandler cancelHandler = delegate(object sender, ConsoleCancelEventArgs eventArgs)
        {
            eventArgs.Cancel = true;
            Interlocked.Exchange(ref cancelRequested, 1);
        };

        try
        {
            Console.CancelKeyPress += cancelHandler;
            job = CreateKillOnCloseJob();

            SECURITY_ATTRIBUTES pipeAttributes = new SECURITY_ATTRIBUTES();
            pipeAttributes.nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES));
            pipeAttributes.bInheritHandle = true;
            if (!CreatePipe(out stdoutRead, out stdoutWrite, ref pipeAttributes, 0) ||
                !SetHandleInformation(stdoutRead, HANDLE_FLAG_INHERIT, 0) ||
                !CreatePipe(out stderrRead, out stderrWrite, ref pipeAttributes, 0) ||
                !SetHandleInformation(stderrRead, HANDLE_FLAG_INHERIT, 0))
            {
                throw LastWin32("Could not create guarded output pipes");
            }

            STARTUPINFO startupInfo = new STARTUPINFO();
            startupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFO));
            startupInfo.dwFlags = STARTF_USESTDHANDLES;
            startupInfo.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
            startupInfo.hStdOutput = stdoutWrite;
            startupInfo.hStdError = stderrWrite;

            string commandLineText = QuoteWindowsArgument(powerShellPath) +
                " -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -EncodedCommand " + encodedBridge;
            StringBuilder commandLine = new StringBuilder(commandLineText);
            bool created = CreateProcess(
                powerShellPath,
                commandLine,
                IntPtr.Zero,
                IntPtr.Zero,
                true,
                CREATE_SUSPENDED,
                IntPtr.Zero,
                workingDirectory,
                ref startupInfo,
                out processInfo);
            if (!created)
            {
                result.ExitCode = 3;
                result.Kind = "blocked";
                result.Reason = "launcher-create-failed";
                result.CleanupConfirmed = true;
                return result;
            }

            CloseIfOpen(ref stdoutWrite);
            CloseIfOpen(ref stderrWrite);

            bool assignmentSucceeded = !forceJobAssignmentFailure &&
                AssignProcessToJobObject(job, processInfo.hProcess);
            if (!assignmentSucceeded)
            {
                bool terminationRequested = TerminateProcess(processInfo.hProcess, 4);
                uint waitResult = terminationRequested
                    ? WaitForSingleObject(processInfo.hProcess, (uint)terminationGraceMs)
                    : WAIT_TIMEOUT;
                bool assignmentCleanupConfirmed =
                    terminationRequested && waitResult == WAIT_OBJECT_0;
                if (forceAssignmentCleanupFailure)
                {
                    assignmentCleanupConfirmed = false;
                }
                string rootPidFile = Environment.GetEnvironmentVariable(
                    "MOSIGAME_GUARD_TEST_ROOT_PID_FILE");
                if (!String.IsNullOrWhiteSpace(rootPidFile))
                {
                    File.WriteAllText(rootPidFile, processInfo.dwProcessId.ToString());
                }
                result.CleanupConfirmed = assignmentCleanupConfirmed;
                if (assignmentCleanupConfirmed)
                {
                    result.ExitCode = 3;
                    result.Kind = "blocked";
                    result.Reason = "job-assignment-failed";
                }
                else
                {
                    result.ExitCode = 4;
                    result.Kind = "internal-error";
                    result.Reason = "job-assignment-cleanup-unconfirmed";
                }
                return result;
            }

            SafeFileHandle stdoutSafe = new SafeFileHandle(stdoutRead, true);
            stdoutRead = IntPtr.Zero;
            SafeFileHandle stderrSafe = new SafeFileHandle(stderrRead, true);
            stderrRead = IntPtr.Zero;
            FileStream stdoutStream = new FileStream(stdoutSafe, FileAccess.Read, 4096, false);
            FileStream stderrStream = new FileStream(stderrSafe, FileAccess.Read, 4096, false);
            Task stdoutTask = Task.Run(delegate
            {
                Pump(stdoutStream, Console.OpenStandardOutput(), jsonMode, true, output, stopwatch);
            });
            Task stderrTask = Task.Run(delegate
            {
                Pump(stderrStream, Console.OpenStandardError(), false, false, output, stopwatch);
            });

            if (setupDelayMs > 0)
            {
                Thread.Sleep(setupDelayMs);
            }
            long setupCompletedMs =
                initialElapsedMs + stopwatch.ElapsedMilliseconds;
            WriteDiagnostic(
                "Guard setup completed after " + setupCompletedMs + " ms.");

            Stopwatch startupStopwatch = Stopwatch.StartNew();
            if (ResumeThread(processInfo.hThread) == UInt32.MaxValue)
            {
                TerminateJobObject(job, 4);
                result.Reason = "launcher-resume-failed";
                result.CleanupConfirmed = WaitForJobEmpty(job, terminationGraceMs);
                return result;
            }
            CloseIfOpen(ref processInfo.hThread);

            WriteDiagnostic("Monitoring started (startup 60s, overall 15m by default).");
            long nextHeartbeat = ((initialElapsedMs / heartbeatMs) + 1) * heartbeatMs;
            bool rootExited = false;
            uint rootExitCode = 4;
            string terminalKind = null;
            string terminalReason = null;
            int terminalExitCode = 4;

            while (true)
            {
                long elapsed = initialElapsedMs + stopwatch.ElapsedMilliseconds;
                long startupElapsed = startupStopwatch.ElapsedMilliseconds;
                if (simulatedInterruptMs > 0 && elapsed >= simulatedInterruptMs)
                {
                    Interlocked.Exchange(ref cancelRequested, 1);
                }
                if (Interlocked.CompareExchange(ref cancelRequested, 0, 0) != 0)
                {
                    terminalKind = "interrupt";
                    terminalReason = "user-interrupt";
                    terminalExitCode = 130;
                    break;
                }

                if (!rootExited && WaitForSingleObject(processInfo.hProcess, 0) == WAIT_OBJECT_0)
                {
                    rootExited = true;
                    if (!GetExitCodeProcess(processInfo.hProcess, out rootExitCode))
                    {
                        terminalKind = "internal-error";
                        terminalReason = "exit-code-read-failed";
                        terminalExitCode = 4;
                        break;
                    }
                }

                uint activeProcesses;
                if (!TryGetActiveProcesses(job, out activeProcesses))
                {
                    terminalKind = "internal-error";
                    terminalReason = "job-query-failed";
                    terminalExitCode = 4;
                    break;
                }
                bool progressNotObserved =
                    Interlocked.CompareExchange(ref output.ProgressObserved, 0, 0) == 0;
                if (progressNotObserved && startupElapsed >= startupTimeoutMs)
                {
                    terminalKind = "blocked";
                    terminalReason = "startup-timeout";
                    terminalExitCode = 3;
                    break;
                }
                if (progressNotObserved &&
                    File.Exists(startupMarkerPath))
                {
                    Interlocked.Exchange(ref output.ProgressObserved, 1);
                    Interlocked.Exchange(ref output.FirstProgressMs, startupElapsed);
                    WriteDiagnostic(
                        "Project CLI startup observed after " + startupElapsed + " ms.");
                }
                if (rootExited && activeProcesses == 0)
                {
                    if (Interlocked.CompareExchange(ref cancelRequested, 0, 0) != 0)
                    {
                        terminalKind = "interrupt";
                        terminalReason = "user-interrupt";
                        terminalExitCode = 130;
                        break;
                    }
                    if (Interlocked.CompareExchange(ref output.ProgressObserved, 0, 0) == 0)
                    {
                        terminalKind = "blocked";
                        terminalReason = "cli-startup-not-observed";
                        terminalExitCode = 3;
                    }
                    else
                    {
                        terminalKind = "child-exit";
                        terminalReason = "natural-exit";
                        terminalExitCode = unchecked((int)rootExitCode);
                    }
                    break;
                }

                if (elapsed >= overallTimeoutMs)
                {
                    terminalKind = "timeout";
                    terminalReason = "overall-timeout";
                    terminalExitCode = 1;
                    break;
                }
                if (elapsed >= nextHeartbeat)
                {
                    WriteDiagnostic("Still running after " + FormatElapsed(elapsed) + ".");
                    nextHeartbeat += heartbeatMs;
                }
                Thread.Sleep(25);
            }

            bool naturalExit = terminalKind == "child-exit";
            bool cleanupConfirmed = true;
            if (!naturalExit)
            {
                if (!TerminateJobObject(job, (uint)terminalExitCode))
                {
                    cleanupConfirmed = false;
                }
                if (!WaitForJobEmpty(job, terminationGraceMs))
                {
                    cleanupConfirmed = false;
                }
                if (forceCleanupFailure)
                {
                    cleanupConfirmed = false;
                }
            }

            if (!Task.WaitAll(new Task[] { stdoutTask, stderrTask }, terminationGraceMs))
            {
                cleanupConfirmed = false;
            }

            result.ProgressObserved = Interlocked.CompareExchange(ref output.ProgressObserved, 0, 0) != 0;
            result.FirstProgressMs = Interlocked.Read(ref output.FirstProgressMs);
            result.CleanupConfirmed = cleanupConfirmed;
            if (!cleanupConfirmed)
            {
                result.ExitCode = 4;
                result.Kind = "internal-error";
                result.Reason = "cleanup-unconfirmed";
                return result;
            }

            result.ExitCode = terminalExitCode;
            result.Kind = terminalKind;
            result.Reason = terminalReason;
            if (naturalExit && jsonMode)
            {
                byte[] bytes;
                lock (output.Sync)
                {
                    bytes = output.JsonStdout.ToArray();
                }
                Stream destination = Console.OpenStandardOutput();
                destination.Write(bytes, 0, bytes.Length);
                destination.Flush();
            }
            return result;
        }
        catch (Exception error)
        {
            WriteDiagnostic("Internal error: " + error.Message);
            if (job != IntPtr.Zero)
            {
                TerminateJobObject(job, 4);
                result.CleanupConfirmed = WaitForJobEmpty(job, terminationGraceMs);
            }
            result.ProgressObserved = Interlocked.CompareExchange(ref output.ProgressObserved, 0, 0) != 0;
            result.FirstProgressMs = Interlocked.Read(ref output.FirstProgressMs);
            return result;
        }
        finally
        {
            Console.CancelKeyPress -= cancelHandler;
            CloseIfOpen(ref stdoutRead);
            CloseIfOpen(ref stdoutWrite);
            CloseIfOpen(ref stderrRead);
            CloseIfOpen(ref stderrWrite);
            CloseIfOpen(ref processInfo.hThread);
            CloseIfOpen(ref processInfo.hProcess);
            CloseIfOpen(ref job);
        }
    }

    private static void Pump(
        Stream source,
        Stream destination,
        bool buffer,
        bool stdout,
        OutputState state,
        Stopwatch stopwatch)
    {
        using (source)
        {
            byte[] bytes = new byte[4096];
            while (true)
            {
                int count = source.Read(bytes, 0, bytes.Length);
                if (count == 0)
                {
                    break;
                }
                if (buffer && stdout)
                {
                    lock (state.Sync)
                    {
                        state.JsonStdout.Write(bytes, 0, count);
                    }
                }
                else
                {
                    destination.Write(bytes, 0, count);
                    destination.Flush();
                }
            }
        }
    }

    private static IntPtr CreateKillOnCloseJob()
    {
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero)
        {
            throw LastWin32("Could not create the process job");
        }
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        int size = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr pointer = Marshal.AllocHGlobal(size);
        try
        {
            Marshal.StructureToPtr(limits, pointer, false);
            if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, pointer, (uint)size))
            {
                CloseHandle(job);
                throw LastWin32("Could not configure the process job");
            }
        }
        finally
        {
            Marshal.FreeHGlobal(pointer);
        }
        return job;
    }

    private static bool WaitForJobEmpty(IntPtr job, int timeoutMs)
    {
        Stopwatch stopwatch = Stopwatch.StartNew();
        while (stopwatch.ElapsedMilliseconds <= timeoutMs)
        {
            uint activeProcesses;
            if (!TryGetActiveProcesses(job, out activeProcesses))
            {
                return false;
            }
            if (activeProcesses == 0)
            {
                return true;
            }
            Thread.Sleep(20);
        }
        return false;
    }

    private static bool TryGetActiveProcesses(IntPtr job, out uint activeProcesses)
    {
        JOBOBJECT_BASIC_ACCOUNTING_INFORMATION accounting;
        bool success = QueryInformationJobObject(
            job,
            JobObjectBasicAccountingInformation,
            out accounting,
            (uint)Marshal.SizeOf(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION)),
            IntPtr.Zero);
        activeProcesses = success ? accounting.ActiveProcesses : 0;
        return success;
    }

    private static string QuoteWindowsArgument(string value)
    {
        if (value.Length > 0 && value.IndexOfAny(new char[] { ' ', '\t', '"' }) < 0)
        {
            return value;
        }
        StringBuilder result = new StringBuilder();
        result.Append('"');
        int backslashes = 0;
        foreach (char character in value)
        {
            if (character == '\\')
            {
                backslashes++;
                continue;
            }
            if (character == '"')
            {
                result.Append('\\', backslashes * 2 + 1);
                result.Append('"');
                backslashes = 0;
                continue;
            }
            result.Append('\\', backslashes);
            backslashes = 0;
            result.Append(character);
        }
        result.Append('\\', backslashes * 2);
        result.Append('"');
        return result.ToString();
    }

    private static string FormatElapsed(long milliseconds)
    {
        TimeSpan elapsed = TimeSpan.FromMilliseconds(milliseconds);
        return elapsed.ToString(@"hh\:mm\:ss");
    }

    private static Exception LastWin32(string message)
    {
        return new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), message);
    }

    private static void WriteDiagnostic(string message)
    {
        Console.Error.WriteLine("[mosigame guard] " + message);
    }

    private static void CloseIfOpen(ref IntPtr handle)
    {
        if (handle != IntPtr.Zero && handle != new IntPtr(-1))
        {
            CloseHandle(handle);
            handle = IntPtr.Zero;
        }
    }
}
'@

try {
    Add-Type -TypeDefinition $guardNativeSource -Language CSharp
    $guardPowerShell = (Get-Process -Id $PID).Path
    [Environment]::SetEnvironmentVariable('MOSIGAME_GUARD_PAYLOAD', $guardPayloadBase64)
    [Environment]::SetEnvironmentVariable(
        'MOSIGAME_GUARD_CLI_ARGUMENTS',
        $guardCliArgumentsBase64
    )
    [Environment]::SetEnvironmentVariable(
        'MOSIGAME_GUARD_STARTUP_MARKER',
        $guardStartupMarker
    )
    $guardForceCleanupFailure = [Environment]::GetEnvironmentVariable(
        'MOSIGAME_GUARD_TEST_FORCE_CLEANUP_FAILURE'
    ) -eq '1'
    $guardForceJobAssignmentFailure = [Environment]::GetEnvironmentVariable(
        'MOSIGAME_GUARD_TEST_FORCE_JOB_ASSIGNMENT_FAILURE'
    ) -eq '1'
    $guardForceAssignmentCleanupFailure = [Environment]::GetEnvironmentVariable(
        'MOSIGAME_GUARD_TEST_FORCE_ASSIGNMENT_CLEANUP_FAILURE'
    ) -eq '1'
    $guardInterruptRaw = [Environment]::GetEnvironmentVariable(
        'MOSIGAME_GUARD_TEST_INTERRUPT_AFTER_MS'
    )
    $guardInterruptMs = 0
    if (-not [string]::IsNullOrWhiteSpace($guardInterruptRaw)) {
        if (-not [int]::TryParse($guardInterruptRaw, [ref]$guardInterruptMs) -or `
            $guardInterruptMs -le 0) {
            throw 'MOSIGAME_GUARD_TEST_INTERRUPT_AFTER_MS must be a positive integer.'
        }
    }
    $guardResult = [MosigameWindowsInvocationGuard]::Run(
        $guardPowerShell,
        $guardBridgeBase64,
        $guardRepositoryRoot,
        $guardJson,
        $guardStartupMarker,
        [int64]$guardStopwatch.ElapsedMilliseconds,
        $guardStartupTimeoutMs,
        $guardOverallTimeoutMs,
        $guardHeartbeatMs,
        $guardTerminationGraceMs,
        $guardForceCleanupFailure,
        $guardForceJobAssignmentFailure,
        $guardForceAssignmentCleanupFailure,
        $guardSetupDelayMs,
        $guardInterruptMs
    )
} catch {
    Complete-GuardFailure -Status 'FAIL' -GuardStatus 'INTERNAL_ERROR' -ExitCode 4 `
        -Reason 'guard-internal-error' -Message $_.Exception.Message `
        -CleanupConfirmed $false
} finally {
    [Environment]::SetEnvironmentVariable('MOSIGAME_GUARD_PAYLOAD', $null)
    [Environment]::SetEnvironmentVariable('MOSIGAME_GUARD_CLI_ARGUMENTS', $null)
    [Environment]::SetEnvironmentVariable('MOSIGAME_GUARD_STARTUP_MARKER', $null)
    Remove-Item -LiteralPath $guardStartupMarker -Force -ErrorAction SilentlyContinue
}

if ($guardResult.FirstProgressMs -ge 0) {
    Write-GuardError ("Project CLI startup: {0} ms." -f $guardResult.FirstProgressMs)
}

switch ($guardResult.Kind) {
    'child-exit' {
        exit $guardResult.ExitCode
    }
    'blocked' {
        $guardMessage = if ($guardResult.Reason -eq 'startup-timeout') {
            'BLOCKED: the Project CLI startup marker was not observed before the startup deadline.'
        } else {
            'BLOCKED: the Project CLI launcher could not be started.'
        }
        if ($guardJson) {
            Write-GuardJsonFailure -Status 'BLOCKED' -GuardStatus 'BLOCKED' `
                -ExitCode 3 -Reason $guardResult.Reason `
                -CleanupConfirmed $guardResult.CleanupConfirmed `
                -ProgressObserved $guardResult.ProgressObserved
        }
        Write-GuardError $guardMessage
        exit 3
    }
    'timeout' {
        if ($guardJson) {
            Write-GuardJsonFailure -Status 'FAIL' -GuardStatus 'FAIL' `
                -ExitCode 1 -Reason $guardResult.Reason `
                -CleanupConfirmed $guardResult.CleanupConfirmed `
                -ProgressObserved $guardResult.ProgressObserved
        }
        Write-GuardError 'FAIL: the overall invocation deadline was exceeded.'
        exit 1
    }
    'interrupt' {
        if ($guardJson) {
            Write-GuardJsonFailure -Status 'FAIL' -GuardStatus 'INTERRUPTED' `
                -ExitCode 130 -Reason $guardResult.Reason `
                -CleanupConfirmed $guardResult.CleanupConfirmed `
                -ProgressObserved $guardResult.ProgressObserved
        }
        Write-GuardError 'Interrupted: the guarded process tree was terminated.'
        exit 130
    }
    default {
        if ($guardJson) {
            Write-GuardJsonFailure -Status 'FAIL' -GuardStatus 'INTERNAL_ERROR' `
                -ExitCode 4 -Reason $guardResult.Reason `
                -CleanupConfirmed $guardResult.CleanupConfirmed `
                -ProgressObserved $guardResult.ProgressObserved
        }
        Write-GuardError 'INTERNAL ERROR: process-tree cleanup or guard execution could not be confirmed.'
        exit 4
    }
}
