// 창 위치 감지 헬퍼 (Design §4.3). 0.5초마다 보이는 창 목록을 JSON 파일로 기록한다.
// 개인정보 원칙(Design §7): 창 제목은 읽지 않는다. 클래스명+좌표만 사용.
// 빌드: csc /nologo /optimize /target:winexe /out:window_probe.exe window_probe_helper.cs
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

class WindowProbe
{
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int val, int size);

    struct RECT { public int L, T, R, B; }

    const int DWMWA_CLOAKED = 14;

    static void Main(string[] args)
    {
        if (args.Length < 1) return;
        string outPath = args[0];
        uint parentPid = args.Length > 1 ? uint.Parse(args[1]) : 0;
        SetProcessDPIAware();

        while (true)
        {
            var sb = new StringBuilder();
            sb.Append("[");
            bool first = true;
            int z = 0;
            EnumWindows((h, l) =>
            {
                if (!IsWindowVisible(h) || IsIconic(h)) return true;
                int cloaked = 0;
                DwmGetWindowAttribute(h, DWMWA_CLOAKED, out cloaked, 4);
                if (cloaked != 0) return true;
                uint pid;
                GetWindowThreadProcessId(h, out pid);
                if (parentPid != 0 && pid == parentPid) return true; // 우리 자신 제외
                var cls = new StringBuilder(128);
                GetClassName(h, cls, 128);
                string c = cls.ToString();
                if (c == "Progman" || c == "WorkerW" || c == "Shell_TrayWnd"
                    || c == "Shell_SecondaryTrayWnd" || c == "NotifyIconOverflowWindow") return true;
                RECT r;
                GetWindowRect(h, out r);
                int w = r.R - r.L, ht = r.B - r.T;
                // 알림 토스트: CoreWindow 계열 중 작은 창
                bool toast = (c == "Windows.UI.Core.CoreWindow" || c == "XamlExplorerHostIslandWindow")
                    && w <= 520 && ht <= 320 && w >= 200;
                if (!toast && (w < 250 || ht < 120)) return true;
                if (!first) sb.Append(",");
                first = false;
                sb.AppendFormat("{{\"i\":{0},\"x\":{1},\"y\":{2},\"w\":{3},\"h\":{4},\"z\":{5},\"t\":{6}}}",
                    h.ToInt64(), r.L, r.T, w, ht, z++, toast ? 1 : 0);
                return true;
            }, IntPtr.Zero);
            sb.Append("]");

            try
            {
                File.WriteAllText(outPath + ".tmp", sb.ToString());
                if (File.Exists(outPath)) File.Delete(outPath);
                File.Move(outPath + ".tmp", outPath);
            }
            catch { }

            // 부모(게임) 종료 시 함께 종료
            if (parentPid != 0)
            {
                try { Process.GetProcessById((int)parentPid); }
                catch { return; }
            }
            Thread.Sleep(500);
        }
    }
}
