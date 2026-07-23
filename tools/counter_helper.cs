// 활동 카운터 헬퍼 (Plan FR-15 v3).
// GetAsyncKeyState 폴링으로 전역 키보드/마우스 keydown edge를 세고 활성 시간을 측정한다.
// 개인정보: 어떤 키인지, 어디를 클릭했는지 절대 저장하지 않는다 (개수와 시간만).
// SetWindowsHookEx 같은 로우레벨 훅은 사용하지 않아 EDR/백신 오탐 위험이 낮다.
// 빌드: csc -nologo -optimize -target:winexe -out:counter.exe counter_helper.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

class CounterHelper
{
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vKey);
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    const int VK_LBUTTON = 0x01;
    const int VK_RBUTTON = 0x02;
    const int VK_MBUTTON = 0x04;
    const int POLL_MS = 30;
    const int WRITE_INTERVAL_MS = 3000;
    const int IDLE_THRESHOLD_MS = 60000;  // 1분 무입력이면 비활성

    static void Main(string[] args)
    {
        if (args.Length < 1) return;
        string outPath = args[0];
        uint parentPid = args.Length > 1 ? uint.Parse(args[1]) : 0;

        long kb = 0, mouse = 0;
        double activeSec = 0.0, fridayActiveSec = 0.0;
        bool[] prev = new bool[256];
        int msSinceWrite = 0;

        while (true)
        {
            for (int vk = 0x08; vk <= 0xFE; vk++)
            {
                bool isDown = (GetAsyncKeyState(vk) & 0x8000) != 0;
                if (isDown && !prev[vk])
                {
                    if (vk == VK_LBUTTON || vk == VK_RBUTTON || vk == VK_MBUTTON) mouse++;
                    else kb++;
                }
                prev[vk] = isDown;
            }
            LASTINPUTINFO lii = new LASTINPUTINFO();
            lii.cbSize = (uint)Marshal.SizeOf(lii);
            if (GetLastInputInfo(ref lii))
            {
                uint idle = (uint)Environment.TickCount - lii.dwTime;
                if (idle < IDLE_THRESHOLD_MS)
                {
                    double dt = POLL_MS / 1000.0;
                    activeSec += dt;
                    if (DateTime.Now.DayOfWeek == DayOfWeek.Friday)
                        fridayActiveSec += dt;
                }
            }

            Thread.Sleep(POLL_MS);
            msSinceWrite += POLL_MS;
            if (msSinceWrite >= WRITE_INTERVAL_MS)
            {
                msSinceWrite = 0;
                try
                {
                    string json = "{\"kb\":" + kb + ",\"mouse\":" + mouse
                        + ",\"active_sec\":" + activeSec.ToString("F1")
                        + ",\"friday_active_sec\":" + fridayActiveSec.ToString("F1") + "}";
                    File.WriteAllText(outPath + ".tmp", json);
                    if (File.Exists(outPath)) File.Delete(outPath);
                    File.Move(outPath + ".tmp", outPath);
                }
                catch { }

                if (parentPid != 0)
                {
                    try { Process.GetProcessById((int)parentPid); }
                    catch { return; }
                }
            }
        }
    }
}
