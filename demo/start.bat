@echo off
setlocal
cd /d "%~dp0.."
set "DEMO_SCRIPT=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:DEMO_SCRIPT,[Text.Encoding]::UTF8); & ([ScriptBlock]::Create(($s -split '(?m)^# POWERSHELL BELOW\r?$',2)[1]))"
exit /b %errorlevel%
# POWERSHELL BELOW
$ErrorActionPreference = 'Stop'
try {
    $root = (Get-Location).Path
    $jar = Join-Path $root 'release\club-manage.jar'
    if (-not (Test-Path -LiteralPath $jar)) { throw '请先运行 demo\build.bat。' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'frontend\node_modules\vite\bin\vite.js'))) { throw '请先在 frontend 目录执行 npm ci。' }
    $java = (Get-Command java.exe -ErrorAction Stop).Source
    $npm = (Get-Command npm.cmd -ErrorAction Stop).Source
    if ($env:SERVER_PORT -and $env:SERVER_PORT -ne '8080') { throw '演示启动使用 8080 端口，请清除 SERVER_PORT 环境变量。' }
    $env:API_TARGET = 'http://localhost:8080'
    foreach ($port in @(8080, 5173)) {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $port)
        try { $listener.Start() } catch { throw "端口 $port 已占用。" } finally { $listener.Stop() }
    }
    # 挂起创建后加入作业，保证 npm 子进程也受控；终端关闭时系统自动清理作业。
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;
public static class DemoHost {
    [StructLayout(LayoutKind.Sequential)] struct BasicLimit {
        public long ProcessTime, JobTime; public uint Flags;
        public UIntPtr MinWorking, MaxWorking; public uint Active;
        public UIntPtr Affinity; public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong A,B,C,D,E,F; }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimit {
        public BasicLimit Basic; public IoCounters Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Startup {
        public int Size; public string Reserved, Desktop, Title;
        public uint X,Y,XSize,YSize,XChars,YChars,Fill,Flags;
        public ushort Show, ReservedSize; public IntPtr ReservedData, Input, Output, Error;
    }
    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr Process, Thread; public uint Id, ThreadId; }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int type, ref ExtendedLimit info, uint length);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcess(string app, System.Text.StringBuilder command, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref Startup start, out ProcessInfo process);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32.dll")] static extern bool TerminateJobObject(IntPtr job, uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr process, out uint code);
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int kind);
    static IntPtr Launch(IntPtr job, string app, string command, string cwd) {
        var start = new Startup { Size=Marshal.SizeOf(typeof(Startup)), Flags=0x100, Input=GetStdHandle(-10), Output=GetStdHandle(-11), Error=GetStdHandle(-12) };
        ProcessInfo pi;
        if (!CreateProcess(app, new System.Text.StringBuilder(command), IntPtr.Zero, IntPtr.Zero, true, 4, IntPtr.Zero, cwd, ref start, out pi)) throw new Win32Exception();
        try {
            if (!AssignProcessToJobObject(job, pi.Process)) throw new Win32Exception();
            if (ResumeThread(pi.Thread)==uint.MaxValue) throw new Win32Exception();
            return pi.Process;
        } catch { TerminateProcess(pi.Process,1); CloseHandle(pi.Process); throw; }
        finally { CloseHandle(pi.Thread); }
    }
    public static int Run(string java, string jar, string npm, string root) {
        IntPtr job=CreateJobObject(IntPtr.Zero,null), backend=IntPtr.Zero, frontend=IntPtr.Zero;
        if(job==IntPtr.Zero) throw new Win32Exception();
        var stopped=new ManualResetEvent(false);
        ConsoleCancelEventHandler cancel=(sender,args)=>{args.Cancel=true;stopped.Set();};
        Console.CancelKeyPress+=cancel;
        try {
            var info=new ExtendedLimit(); info.Basic.Flags=0x2000;
            if(!SetInformationJobObject(job,9,ref info,(uint)Marshal.SizeOf(typeof(ExtendedLimit)))) throw new Win32Exception();
            backend=Launch(job,java,"\""+java+"\" -jar \""+jar+"\"",root);
            string cmd=Environment.GetEnvironmentVariable("ComSpec");
            frontend=Launch(job,cmd,"\""+cmd+"\" /d /s /c \"\""+npm+"\" run dev -- --host 127.0.0.1 --port 5173 --strictPort\"",System.IO.Path.Combine(root,"frontend"));
            Console.WriteLine("访问 http://localhost:5173 。按 Ctrl+C 或关闭此终端停止前后端。");
            while(!stopped.WaitOne(200)) {
                foreach(var process in new[]{backend,frontend}) {
                    if(WaitForSingleObject(process,0)==0) {
                        uint code; GetExitCodeProcess(process,out code);
                        Console.WriteLine("服务已退出，正在停止另一服务。");
                        return (int)code;
                    }
                }
            }
            return 0;
        } finally {
            TerminateJobObject(job,0);
            if(backend!=IntPtr.Zero) { WaitForSingleObject(backend,5000); CloseHandle(backend); }
            if(frontend!=IntPtr.Zero) { WaitForSingleObject(frontend,5000); CloseHandle(frontend); }
            CloseHandle(job); Console.CancelKeyPress-=cancel; stopped.Dispose();
        }
    }
}
'@
    exit [DemoHost]::Run($java, $jar, $npm, $root)
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}
