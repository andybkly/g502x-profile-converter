# G502 X Profile Converter for Windows 10/11
# Copies wired G502 X button assignments to G502 X Lightspeed assignment slots.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web.Extensions

$sqliteSource = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class WinSqlite {
    const string Dll = "winsqlite3.dll";
    public const int OK = 0, ROW = 100, DONE = 101, OPEN_READONLY = 1, OPEN_READWRITE = 2;
    static readonly IntPtr TRANSIENT = new IntPtr(-1);

    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_open_v2(byte[] name, out IntPtr db, int flags, IntPtr vfs);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_close(IntPtr db);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_errmsg(IntPtr db);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int bytes, out IntPtr stmt, IntPtr tail);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_step(IntPtr stmt);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_finalize(IntPtr stmt);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_blob(IntPtr stmt, int col);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_column_bytes(IntPtr stmt, int col);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern long sqlite3_column_int64(IntPtr stmt, int col);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_text(IntPtr stmt, int col);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_bind_blob(IntPtr stmt, int index, byte[] value, int bytes, IntPtr destructor);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_bind_int64(IntPtr stmt, int index, long value);

    static byte[] Utf8(string s) { return Encoding.UTF8.GetBytes(s + "\0"); }
    static string Error(IntPtr db) { return Marshal.PtrToStringAnsi(sqlite3_errmsg(db)); }

    static IntPtr Open(string path, int flags) {
        IntPtr db; int rc = sqlite3_open_v2(Utf8(path), out db, flags, IntPtr.Zero);
        if (rc != OK) throw new Exception("Could not open database: " + Error(db));
        return db;
    }
    static IntPtr Prepare(IntPtr db, string sql) {
        IntPtr stmt; int rc = sqlite3_prepare_v2(db, Utf8(sql), -1, out stmt, IntPtr.Zero);
        if (rc != OK) throw new Exception("SQLite error: " + Error(db));
        return stmt;
    }
    public static byte[] ReadData(string path, out long id) {
        IntPtr db = Open(path, OPEN_READONLY), stmt = IntPtr.Zero;
        try {
            stmt = Prepare(db, "SELECT _id, FILE FROM DATA ORDER BY _id LIMIT 1");
            if (sqlite3_step(stmt) != ROW) throw new Exception("The DATA table is empty.");
            id = sqlite3_column_int64(stmt, 0);
            int size = sqlite3_column_bytes(stmt, 1); IntPtr ptr = sqlite3_column_blob(stmt, 1);
            byte[] result = new byte[size]; Marshal.Copy(ptr, result, 0, size); return result;
        } finally { if (stmt != IntPtr.Zero) sqlite3_finalize(stmt); sqlite3_close(db); }
    }
    public static void WriteData(string path, long id, byte[] data) {
        IntPtr db = Open(path, OPEN_READWRITE), stmt = IntPtr.Zero;
        try {
            Execute(db, "BEGIN IMMEDIATE");
            stmt = Prepare(db, "UPDATE DATA SET FILE=? WHERE _id=?");
            if (sqlite3_bind_blob(stmt, 1, data, data.Length, TRANSIENT) != OK || sqlite3_bind_int64(stmt, 2, id) != OK)
                throw new Exception("Could not bind converted data: " + Error(db));
            if (sqlite3_step(stmt) != DONE) throw new Exception("Could not update database: " + Error(db));
            sqlite3_finalize(stmt); stmt = IntPtr.Zero;
            Execute(db, "COMMIT");
        } catch { try { Execute(db, "ROLLBACK"); } catch {} throw; }
        finally { if (stmt != IntPtr.Zero) sqlite3_finalize(stmt); sqlite3_close(db); }
    }
    static void Execute(IntPtr db, string sql) {
        IntPtr stmt = Prepare(db, sql);
        try { int rc = sqlite3_step(stmt); if (rc != DONE && rc != ROW) throw new Exception("SQLite error: " + Error(db)); }
        finally { sqlite3_finalize(stmt); }
    }
    public static string IntegrityCheck(string path) {
        IntPtr db = Open(path, OPEN_READONLY), stmt = IntPtr.Zero;
        try {
            stmt = Prepare(db, "PRAGMA integrity_check");
            if (sqlite3_step(stmt) != ROW) return "No result";
            IntPtr p = sqlite3_column_text(stmt, 0); return Marshal.PtrToStringAnsi(p);
        } finally { if (stmt != IntPtr.Zero) sqlite3_finalize(stmt); sqlite3_close(db); }
    }
}
'@
Add-Type -TypeDefinition $sqliteSource -Language CSharp

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show($Message, 'G502 X Profile Converter', 'OK', 'Error') | Out-Null
}

try {
    $open = New-Object System.Windows.Forms.OpenFileDialog
    $open.Title = 'Select your LGHUB settings.db (close G Hub first)'
    $open.Filter = 'LGHUB settings.db|settings.db|Database files (*.db)|*.db|All files (*.*)|*.*'
    $defaultFolder = Join-Path $env:LOCALAPPDATA 'LGHUB'
    if (Test-Path $defaultFolder) { $open.InitialDirectory = $defaultFolder }
    if ($open.ShowDialog() -ne 'OK') { exit 0 }
    $source = $open.FileName

    [long]$rowId = 0
    $bytes = [WinSqlite]::ReadData($source, [ref]$rowId)
    $jsonText = [Text.Encoding]::UTF8.GetString($bytes)
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = [int]::MaxValue
    $serializer.RecursionLimit = 500
    $root = $serializer.DeserializeObject($jsonText)
    if (-not $root.ContainsKey('profiles') -or -not $root['profiles'].ContainsKey('profiles')) {
        throw 'This database does not contain the expected LGHUB profiles structure.'
    }

    $profileCount = 0
    $assignmentCount = 0
    foreach ($profile in $root['profiles']['profiles']) {
        if (-not $profile.ContainsKey('assignments')) { continue }
        $assignmentList = New-Object System.Collections.ArrayList
        [void]$assignmentList.AddRange([object[]]$profile['assignments'])
        $profile['assignments'] = $assignmentList
        $wired = @{}
        $wireless = @{}
        foreach ($assignment in $assignmentList) {
            if (-not $assignment.ContainsKey('slotId')) { continue }
            $slot = [string]$assignment['slotId']
            if ($slot.StartsWith('g502x-lightspeed_')) { $wireless[$slot.Substring(17)] = $assignment }
            elseif ($slot.StartsWith('g502x_')) { $wired[$slot.Substring(6)] = $assignment }
        }
        $changed = 0
        foreach ($suffix in $wired.Keys) {
            if ($suffix -eq 'mouse_settings' -or $suffix -eq 'lighting_setting_firmware') { continue }
            $sourceAssignment = $wired[$suffix]
            if ($wireless.ContainsKey($suffix)) {
                $target = $wireless[$suffix]
                if ([string]$target['cardId'] -ne [string]$sourceAssignment['cardId']) {
                    $target['cardId'] = $sourceAssignment['cardId']; $changed++
                }
            } else {
                $newAssignment = @{}
                foreach ($key in $sourceAssignment.Keys) { $newAssignment[$key] = $sourceAssignment[$key] }
                $newAssignment['slotId'] = 'g502x-lightspeed_' + $suffix
                [void]$assignmentList.Add($newAssignment)
                $changed++
            }
        }
        if ($changed -gt 0) { $profileCount++; $assignmentCount += $changed }
    }

    if ($assignmentCount -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('No differing G502 X assignments were found. The Lightspeed profiles already match.', 'Nothing to convert', 'OK', 'Information') | Out-Null
        exit 0
    }

    $answer = [System.Windows.Forms.MessageBox]::Show("Found $assignmentCount assignments to transfer across $profileCount profiles.`r`n`r`nCreate a converted copy now?", 'Ready to convert', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { exit 0 }

    $save = New-Object System.Windows.Forms.SaveFileDialog
    $save.Title = 'Save the converted database'
    $save.Filter = 'Database files (*.db)|*.db'
    $save.InitialDirectory = [IO.Path]::GetDirectoryName($source)
    $save.FileName = 'settings-G502X-Lightspeed-converted.db'
    if ($save.ShowDialog() -ne 'OK') { exit 0 }
    $destination = $save.FileName
    if ([IO.Path]::GetFullPath($destination) -eq [IO.Path]::GetFullPath($source)) {
        throw 'Choose a different filename. The converter will not overwrite your original settings.db.'
    }

    Copy-Item -LiteralPath $source -Destination $destination -Force
    $convertedJson = $serializer.Serialize($root)
    [WinSqlite]::WriteData($destination, $rowId, [Text.Encoding]::UTF8.GetBytes($convertedJson))
    $integrity = [WinSqlite]::IntegrityCheck($destination)
    if ($integrity -ne 'ok') { Remove-Item -LiteralPath $destination -Force; throw "The converted database failed validation: $integrity" }

    [System.Windows.Forms.MessageBox]::Show("Conversion complete.`r`n`r`nUpdated $assignmentCount assignments across $profileCount profiles.`r`n`r`nCreated:`r`n$destination`r`n`r`nYour original database was not changed.", 'Conversion complete', 'OK', 'Information') | Out-Null
} catch {
    Show-Error ("Conversion failed. Your original database was not changed.`r`n`r`n" + $_.Exception.Message)
    exit 1
}
