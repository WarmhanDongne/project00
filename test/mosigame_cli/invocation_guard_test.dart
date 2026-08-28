import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  if (!Platform.isWindows) {
    test('Windows invocation guard tests are skipped off Windows', () {});
    return;
  }

  late Directory temporaryDirectory;
  late String guardPath;
  late String fakeLauncherPath;
  late String controlSignalDriverPath;
  final spawnedProcesses = <Process>[];

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mosigame-invocation-guard-',
    );
    guardPath = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'tool${Platform.pathSeparator}invoke_mosigame.ps1',
    ).absolute.path;
    fakeLauncherPath = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}fake_launcher.cmd',
    ).path;
    await File(fakeLauncherPath).writeAsString(_fakeLauncher);
    await File(
      '${temporaryDirectory.path}${Platform.pathSeparator}fake_child.ps1',
    ).writeAsString(_fakeChild);
    controlSignalDriverPath = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      'control_signal_driver.ps1',
    ).path;
    await File(controlSignalDriverPath).writeAsString(_controlSignalDriver);
  });

  tearDown(() async {
    for (final process in spawnedProcesses) {
      process.kill();
    }
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'forwards stdout and stderr and preserves natural exit codes 0-4',
    () async {
      for (var exitCode = 0; exitCode <= 4; exitCode++) {
        final result = await _runGuard(
          guardPath,
          fakeLauncherPath,
          const <String>['doctor'],
          <String, String>{
            'MOSIGAME_FAKE_MODE': 'normal',
            'MOSIGAME_FAKE_EXIT_CODE': '$exitCode',
          },
        );

        expect(result.exitCode, exitCode);
        expect(result.stdout as String, contains('child-out'));
        expect(result.stderr as String, contains('child-err'));
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'preserves argument order and special values through a cmd launcher',
    () async {
      final argumentsPath = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}arguments.json',
      ).path;
      const arguments = <String>[
        'test',
        'space value',
        'quote"value',
        'amp&value',
        'percent%value',
        'caret^value',
      ];

      final result = await _runGuard(
        guardPath,
        fakeLauncherPath,
        arguments,
        <String, String>{
          'MOSIGAME_FAKE_MODE': 'normal',
          'MOSIGAME_FAKE_EXIT_CODE': '0',
          'MOSIGAME_FAKE_ARGUMENTS_FILE': argumentsPath,
        },
      );

      expect(result.exitCode, 0);
      final recorded = jsonDecode(await File(argumentsPath).readAsString());
      expect(recorded, arguments);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'startup silence is BLOCKED and the batch descendant is removed',
    () async {
      final pidPath = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}startup.pid',
      ).path;
      final result = await _runGuard(
        guardPath,
        fakeLauncherPath,
        const <String>['doctor'],
        <String, String>{
          'MOSIGAME_FAKE_MODE': 'startup-hang',
          'MOSIGAME_FAKE_PID_FILE': pidPath,
          'MOSIGAME_GUARD_TEST_STARTUP_TIMEOUT_MS': '15000',
        },
      );

      expect(result.exitCode, 3, reason: '${result.stdout}\n${result.stderr}');
      expect(
        result.stderr as String,
        contains('Project CLI startup marker was not observed'),
      );
      final pid = int.parse(await File(pidPath).readAsString());
      expect(await _processExists(pid), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'overall timeout is FAIL, emits heartbeat, and preserves other processes',
    () async {
      final unrelated = await Process.start('powershell.exe', const <String>[
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Sleep -Seconds 30',
      ]);
      spawnedProcesses.add(unrelated);
      final pidPath = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}overall.pid',
      ).path;

      final result = await _runGuard(
        guardPath,
        fakeLauncherPath,
        const <String>['validate', '--full'],
        <String, String>{
          'MOSIGAME_FAKE_MODE': 'overall-hang',
          'MOSIGAME_FAKE_PID_FILE': pidPath,
          'MOSIGAME_GUARD_TEST_OVERALL_TIMEOUT_MS': '15000',
          'MOSIGAME_GUARD_TEST_HEARTBEAT_MS': '500',
        },
      );

      expect(result.exitCode, 1);
      expect(result.stderr as String, contains('child-progress'));
      expect(result.stderr as String, contains('Still running'));
      expect(result.stderr as String, contains('overall invocation deadline'));
      final pid = int.parse(await File(pidPath).readAsString());
      expect(await _processExists(pid), isFalse);
      expect(await _processExists(unrelated.pid), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'cleanup uncertainty is an internal error after the tree is removed',
    () async {
      final pidPath = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}cleanup.pid',
      ).path;
      final result = await _runGuard(
        guardPath,
        fakeLauncherPath,
        const <String>['doctor'],
        <String, String>{
          'MOSIGAME_FAKE_MODE': 'startup-hang',
          'MOSIGAME_FAKE_PID_FILE': pidPath,
          'MOSIGAME_GUARD_TEST_STARTUP_TIMEOUT_MS': '15000',
          'MOSIGAME_GUARD_TEST_FORCE_CLEANUP_FAILURE': '1',
        },
      );

      expect(result.exitCode, 4);
      expect(result.stderr as String, contains('INTERNAL ERROR'));
      final pid = int.parse(await File(pidPath).readAsString());
      expect(await _processExists(pid), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'job assignment failure is BLOCKED only when root cleanup is confirmed',
    () async {
      final rootPidPath = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}assignment.pid',
      ).path;
      final result = await _runGuard(
        guardPath,
        fakeLauncherPath,
        const <String>['--json', 'doctor'],
        <String, String>{
          'MOSIGAME_FAKE_MODE': 'startup-hang',
          'MOSIGAME_GUARD_TEST_FORCE_JOB_ASSIGNMENT_FAILURE': '1',
          'MOSIGAME_GUARD_TEST_ROOT_PID_FILE': rootPidPath,
        },
      );

      expect(result.exitCode, 3, reason: '${result.stdout}\n${result.stderr}');
      final decoded =
          jsonDecode(result.stdout as String) as Map<String, Object?>;
      final guard = decoded['guard']! as Map<String, Object?>;
      expect(decoded['status'], 'BLOCKED');
      expect(decoded['command'], 'doctor');
      expect(guard['reason'], 'job-assignment-failed');
      expect(guard['cleanupConfirmed'], isTrue);
      final rootPid = int.parse(await File(rootPidPath).readAsString());
      expect(await _processExists(rootPid), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'unconfirmed assignment-failure cleanup is INTERNAL ERROR',
    () async {
      final rootPidPath = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        'assignment-cleanup.pid',
      ).path;
      final result = await _runGuard(
        guardPath,
        fakeLauncherPath,
        const <String>['doctor', '--json'],
        <String, String>{
          'MOSIGAME_FAKE_MODE': 'startup-hang',
          'MOSIGAME_GUARD_TEST_FORCE_JOB_ASSIGNMENT_FAILURE': '1',
          'MOSIGAME_GUARD_TEST_FORCE_ASSIGNMENT_CLEANUP_FAILURE': '1',
          'MOSIGAME_GUARD_TEST_ROOT_PID_FILE': rootPidPath,
        },
      );

      expect(result.exitCode, 4);
      final decoded =
          jsonDecode(result.stdout as String) as Map<String, Object?>;
      final guard = decoded['guard']! as Map<String, Object?>;
      expect(decoded['status'], 'FAIL');
      expect(guard['status'], 'INTERNAL_ERROR');
      expect(
        guard['reason'],
        'job-assignment-cleanup-unconfirmed',
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(guard['cleanupConfirmed'], isFalse);
      final rootPid = int.parse(await File(rootPidPath).readAsString());
      expect(await _processExists(rootPid), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'interrupt simulation returns 130 and removes descendants',
    () async {
      final pidPath = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}interrupt.pid',
      ).path;
      final result = await _runGuard(
        guardPath,
        fakeLauncherPath,
        const <String>['doctor'],
        <String, String>{
          'MOSIGAME_FAKE_MODE': 'overall-hang',
          'MOSIGAME_FAKE_PID_FILE': pidPath,
          'MOSIGAME_GUARD_TEST_INTERRUPT_AFTER_MS': '15000',
        },
      );

      expect(result.exitCode, 130);
      expect(result.stderr as String, contains('Interrupted'));
      final pid = int.parse(await File(pidPath).readAsString());
      expect(await _processExists(pid), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'real Ctrl+C returns 130 and removes the guarded descendant tree',
    () async {
      final pidPath = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}real-interrupt.pid',
      ).path;
      final result = await _runGuardWithRealCtrlC(
        controlSignalDriverPath,
        guardPath,
        fakeLauncherPath,
        pidPath,
      );

      expect(
        result.exitCode,
        130,
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(result.stderr as String, contains('Interrupted'));
      final pid = int.parse(await File(pidPath).readAsString());
      expect(await _processExists(pid), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test(
    'normal JSON is passed through unchanged',
    () async {
      const childJson =
          '{"schemaVersion":1,"command":"doctor","status":"PASS","exitCode":0}';
      final result = await _runGuard(
        guardPath,
        fakeLauncherPath,
        const <String>['doctor', '--json'],
        const <String, String>{
          'MOSIGAME_FAKE_MODE': 'json',
          'MOSIGAME_FAKE_JSON': childJson,
        },
      );

      expect(result.exitCode, 0);
      expect(result.stdout, childJson);
      expect(jsonDecode(result.stdout as String), isA<Map<String, Object?>>());
      expect(result.stderr as String, contains('[mosigame guard]'));
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'guard BLOCKED JSON finds the command before or after --json',
    () async {
      for (final arguments in const <List<String>>[
        <String>['doctor', '--json'],
        <String>['--json', 'doctor'],
      ]) {
        final result = await _runGuard(
          guardPath,
          fakeLauncherPath,
          arguments,
          const <String, String>{
            'MOSIGAME_FAKE_MODE': 'startup-hang',
            'MOSIGAME_GUARD_TEST_STARTUP_TIMEOUT_MS': '15000',
          },
        );

        expect(result.exitCode, 3);
        final stdoutText = result.stdout as String;
        final decoded = jsonDecode(stdoutText) as Map<String, Object?>;
        expect(decoded['schemaVersion'], 1);
        expect(decoded['resultType'], 'invocationGuard');
        expect(decoded['command'], 'doctor');
        expect(decoded['status'], 'BLOCKED');
        expect(decoded['exitCode'], 3);
        expect(stdoutText.trim().split('\n'), hasLength(1));
        expect(stdoutText, isNot(contains('Still running')));
        expect(result.stderr as String, contains('BLOCKED'));
      }
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

Future<ProcessResult> _runGuard(
  String guardPath,
  String fakeLauncherPath,
  List<String> arguments,
  Map<String, String> environment,
) {
  return Process.run(
    'pwsh.exe',
    <String>[
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      guardPath,
      ...arguments,
    ],
    environment: <String, String>{
      'MOSIGAME_GUARD_TEST_EXECUTABLE': fakeLauncherPath,
      'MOSIGAME_GUARD_TEST_STARTUP_TIMEOUT_MS': '30000',
      'MOSIGAME_GUARD_TEST_OVERALL_TIMEOUT_MS': '30000',
      'MOSIGAME_GUARD_TEST_HEARTBEAT_MS': '5000',
      'MOSIGAME_GUARD_TEST_TERMINATION_GRACE_MS': '2000',
      ...environment,
    },
  );
}

Future<ProcessResult> _runGuardWithRealCtrlC(
  String driverPath,
  String guardPath,
  String fakeLauncherPath,
  String descendantPidPath,
) {
  return Process.run(
    'pwsh.exe',
    <String>[
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      driverPath,
      guardPath,
      descendantPidPath,
    ],
    environment: <String, String>{
      'MOSIGAME_GUARD_TEST_EXECUTABLE': fakeLauncherPath,
      'MOSIGAME_GUARD_TEST_STARTUP_TIMEOUT_MS': '30000',
      'MOSIGAME_GUARD_TEST_OVERALL_TIMEOUT_MS': '30000',
      'MOSIGAME_GUARD_TEST_HEARTBEAT_MS': '5000',
      'MOSIGAME_GUARD_TEST_TERMINATION_GRACE_MS': '2000',
      'MOSIGAME_FAKE_MODE': 'overall-hang',
      'MOSIGAME_FAKE_PID_FILE': descendantPidPath,
    },
  );
}

Future<bool> _processExists(int pid) async {
  final result = await Process.run('tasklist.exe', <String>[
    '/FI',
    'PID eq $pid',
    '/FO',
    'CSV',
    '/NH',
  ]);
  return (result.stdout as String).contains('"$pid"');
}

const _fakeLauncher = r'''@echo off
pwsh.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0fake_child.ps1"
exit /b %ERRORLEVEL%
''';

const _fakeChild = r'''
$mode = $env:MOSIGAME_FAKE_MODE
if ($mode -ne 'startup-hang') {
    $marker = [IO.File]::Create($env:MOSIGAME_GUARD_STARTUP_MARKER)
    $marker.Dispose()
}
if (-not [string]::IsNullOrWhiteSpace($env:MOSIGAME_FAKE_PID_FILE)) {
    [IO.File]::WriteAllText($env:MOSIGAME_FAKE_PID_FILE, "$PID")
}
if (-not [string]::IsNullOrWhiteSpace($env:MOSIGAME_FAKE_ARGUMENTS_FILE)) {
    $argumentBytes = [Convert]::FromBase64String($env:MOSIGAME_GUARD_CLI_ARGUMENTS)
    $json = [Text.Encoding]::UTF8.GetString($argumentBytes)
    [IO.File]::WriteAllText($env:MOSIGAME_FAKE_ARGUMENTS_FILE, $json)
}
switch ($mode) {
    'normal' {
        [Console]::Out.WriteLine('child-out')
        [Console]::Error.WriteLine('child-err')
        exit [int]$env:MOSIGAME_FAKE_EXIT_CODE
    }
    'json' {
        [Console]::Out.Write($env:MOSIGAME_FAKE_JSON)
        exit 0
    }
    'overall-hang' {
        [Console]::Error.WriteLine('child-progress')
        while ($true) { Start-Sleep -Milliseconds 100 }
    }
    'startup-hang' {
        while ($true) { Start-Sleep -Milliseconds 100 }
    }
    default { exit 4 }
}
''';

const _controlSignalDriver = r'''
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$GuardPath,
    [Parameter(Mandatory = $true, Position = 1)][string]$DescendantPidPath
)

$ErrorActionPreference = 'Stop'
$driverSource = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class MosigameCtrlCDriver
{
    private const uint CREATE_NEW_CONSOLE = 0x00000010;
    private const uint STARTF_USESHOWWINDOW = 0x00000001;
    private const uint STARTF_USESTDHANDLES = 0x00000100;
    private const short SW_HIDE = 0;
    private const uint CTRL_C_EVENT = 0;
    private const uint WAIT_OBJECT_0 = 0;
    private const uint WAIT_TIMEOUT = 258;
    private const int STD_INPUT_HANDLE = -10;
    private const int STD_OUTPUT_HANDLE = -11;
    private const int STD_ERROR_HANDLE = -12;

    private delegate bool ConsoleCtrlHandler(uint controlType);

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
    private static extern bool FreeConsole();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AttachConsole(uint processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleCtrlHandler(
        ConsoleCtrlHandler handler,
        bool add);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GenerateConsoleCtrlEvent(
        uint controlEvent,
        uint processGroupId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(IntPtr process, uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    public static int Run(
        string powerShellPath,
        string guardPath,
        string workingDirectory,
        string descendantPidPath)
    {
        STARTUPINFO startupInfo = new STARTUPINFO();
        startupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        startupInfo.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
        startupInfo.wShowWindow = SW_HIDE;
        startupInfo.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
        startupInfo.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
        startupInfo.hStdError = GetStdHandle(STD_ERROR_HANDLE);

        string commandLineText = QuoteWindowsArgument(powerShellPath) +
            " -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " +
            QuoteWindowsArgument(guardPath) + " doctor";
        PROCESS_INFORMATION processInfo;
        bool created = CreateProcess(
            powerShellPath,
            new StringBuilder(commandLineText),
            IntPtr.Zero,
            IntPtr.Zero,
            true,
            CREATE_NEW_CONSOLE,
            IntPtr.Zero,
            workingDirectory,
            ref startupInfo,
            out processInfo);
        if (!created)
        {
            return 201;
        }

        CloseHandle(processInfo.hThread);
        try
        {
            Stopwatch startupWait = Stopwatch.StartNew();
            while (!File.Exists(descendantPidPath) && startupWait.ElapsedMilliseconds < 30000)
            {
                if (WaitForSingleObject(processInfo.hProcess, 0) == WAIT_OBJECT_0)
                {
                    uint earlyExit;
                    return GetExitCodeProcess(processInfo.hProcess, out earlyExit)
                        ? unchecked((int)earlyExit)
                        : 202;
                }
                Thread.Sleep(25);
            }
            if (!File.Exists(descendantPidPath))
            {
                TerminateAndWait(processInfo.hProcess);
                return 203;
            }

            FreeConsole();
            if (!AttachConsole(processInfo.dwProcessId) ||
                !SetConsoleCtrlHandler(null, true) ||
                !GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0))
            {
                TerminateAndWait(processInfo.hProcess);
                return 204;
            }

            if (WaitForSingleObject(processInfo.hProcess, 15000) != WAIT_OBJECT_0)
            {
                TerminateAndWait(processInfo.hProcess);
                return 205;
            }
            uint exitCode;
            return GetExitCodeProcess(processInfo.hProcess, out exitCode)
                ? unchecked((int)exitCode)
                : 206;
        }
        finally
        {
            CloseHandle(processInfo.hProcess);
        }
    }

    private static void TerminateAndWait(IntPtr process)
    {
        TerminateProcess(process, 207);
        WaitForSingleObject(process, 5000);
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
}
'@

Add-Type -TypeDefinition $driverSource -Language CSharp
$driverPowerShell = (Get-Process -Id $PID).Path
$driverExit = [MosigameCtrlCDriver]::Run(
    $driverPowerShell,
    $GuardPath,
    (Split-Path -Parent $GuardPath),
    $DescendantPidPath
)
exit $driverExit
''';
