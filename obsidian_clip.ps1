#Requires -Version 5.1
# OBSIDIAN QUICK CLIP
# Запуск: start.vbs  |  При ошибке — см. obsidian_clip.log рядом со скриптом

$ScriptDir    = if ($PSScriptRoot) { $PSScriptRoot } `
                else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$SettingsFile = Join-Path $ScriptDir "obsidian_clip.cfg"
$LogFile      = Join-Path $ScriptDir "obsidian_clip.log"

function Write-Log($msg) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$stamp] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 3
Write-Log "=== START  ScriptDir=$ScriptDir"
Write-Log "SettingsFile=$SettingsFile  Exists=$(Test-Path $SettingsFile)"

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing       -ErrorAction Stop
    Write-Log "Assemblies OK"
} catch {
    Write-Log "FATAL assembly: $_"
    exit 1
}

try {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Diagnostics;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Collections.Generic;

// ════════════════════════════════════════════════════════════
// Настройки
// ════════════════════════════════════════════════════════════
public class ClipSettings {
    public static readonly string[] KEY_NAMES = {
        "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"
    };
    public static readonly uint[] KEY_VKS = {
        0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B
    };

    public string SettingsPath  { get; set; }
    public string VaultPath     { get; set; }
    public string Inbox         { get; set; }
    public string Attachments   { get; set; }
    public string DatePropName  { get; set; }
    public string DateFormat    { get; set; }
    public List<string[]> Props { get; set; }
    public string TemplaterCmd  { get; set; }
    public bool   HotkeyCtrl   { get; set; }
    public bool   HotkeyAlt    { get; set; }
    public bool   HotkeyShift  { get; set; }
    public uint   HotkeyVk     { get; set; }

    public ClipSettings(string path) {
        SettingsPath = path;
        Attachments  = "Serv\\Attachments";
        DatePropName = "date";
        DateFormat   = "yyyy-MM-dd";
        Props        = new List<string[]>();
        HotkeyCtrl   = true;
        HotkeyAlt    = true;
        HotkeyShift  = false;
        HotkeyVk     = 0x77;
    }

    public bool Load() {
        if (!File.Exists(SettingsPath)) return false;
        try {
            var pnames  = new Dictionary<int, string>();
            var pvalues = new Dictionary<int, string>();
            string legacyName = null, legacyVal = null;
            foreach (string raw in File.ReadAllLines(SettingsPath, Encoding.UTF8)) {
                int eq = raw.IndexOf('=');
                if (eq < 0) continue;
                string k = raw.Substring(0, eq).Trim().ToLower();
                string v = raw.Substring(eq + 1);
                switch (k) {
                    case "vaultpath":    VaultPath    = v; break;
                    case "inbox":        Inbox        = v; break;
                    case "attachments":  Attachments  = v; break;
                    case "datepropname": DatePropName = v; break;
                    case "dateformat":   DateFormat   = v; break;
                    case "templatercmd": TemplaterCmd = v; break;
                    case "hotkey_ctrl":  HotkeyCtrl  = (v == "true"); break;
                    case "hotkey_alt":   HotkeyAlt   = (v == "true"); break;
                    case "hotkey_shift": HotkeyShift = (v == "true"); break;
                    case "hotkey_vk": {
                        uint vk; if (uint.TryParse(v, out vk)) HotkeyVk = vk; break;
                    }
                    case "propname":  legacyName = v; break;
                    case "propvalue": legacyVal  = v; break;
                    default: {
                        if (k.StartsWith("prop_name_")) {
                            int idx; if (int.TryParse(k.Substring(10), out idx)) pnames[idx] = v;
                        } else if (k.StartsWith("prop_value_")) {
                            int idx; if (int.TryParse(k.Substring(11), out idx)) pvalues[idx] = v;
                        }
                        break;
                    }
                }
            }
            Props = new List<string[]>();
            for (int i = 0; i < 100; i++) {
                if (!pnames.ContainsKey(i)) break;
                Props.Add(new string[] { pnames[i], pvalues.ContainsKey(i) ? pvalues[i] : "" });
            }
            if (Props.Count == 0 && legacyName != null)
                Props.Add(new string[] { legacyName, legacyVal ?? "" });
            return !string.IsNullOrEmpty(VaultPath);
        } catch { return false; }
    }

    public void Save() {
        var lines = new List<string>();
        lines.Add("vaultpath="    + (VaultPath    ?? ""));
        lines.Add("inbox="        + (Inbox        ?? ""));
        lines.Add("attachments="  + (Attachments  ?? ""));
        lines.Add("datepropname=" + (DatePropName ?? "date"));
        lines.Add("dateformat="   + (DateFormat   ?? "yyyy-MM-dd"));
        lines.Add("templatercmd=" + (TemplaterCmd ?? ""));
        lines.Add("hotkey_ctrl="  + HotkeyCtrl.ToString().ToLower());
        lines.Add("hotkey_alt="   + HotkeyAlt.ToString().ToLower());
        lines.Add("hotkey_shift=" + HotkeyShift.ToString().ToLower());
        lines.Add("hotkey_vk="    + HotkeyVk.ToString());
        for (int i = 0; i < Props.Count; i++) {
            lines.Add("prop_name_"  + i + "=" + Props[i][0]);
            lines.Add("prop_value_" + i + "=" + (Props[i].Length > 1 ? Props[i][1] : ""));
        }
        File.WriteAllLines(SettingsPath, lines.ToArray(), Encoding.UTF8);
    }

    public uint GetMod() {
        uint m = 0;
        if (HotkeyCtrl)  m |= 0x0002;
        if (HotkeyAlt)   m |= 0x0001;
        if (HotkeyShift) m |= 0x0004;
        return m;
    }

    public string GetHotkeyDisplay() {
        string s = "";
        if (HotkeyCtrl)  s += "Ctrl+";
        if (HotkeyAlt)   s += "Alt+";
        if (HotkeyShift) s += "Shift+";
        int idx = Array.IndexOf(KEY_VKS, HotkeyVk);
        return s + (idx >= 0 ? KEY_NAMES[idx] : "?");
    }
}

// ════════════════════════════════════════════════════════════
// Окно настроек
// ════════════════════════════════════════════════════════════
public class SettingsForm : Form {
    public ClipSettings Result;
    TextBox txVault, txInbox, txAttach, txDateProp, txDate, txTmpl;
    DataGridView dgvProps;
    CheckBox ckCtrl, ckAlt, ckShift;
    ComboBox cbKey;

    public SettingsForm(ClipSettings s) {
        Text = "Настройки Obsidian Clip";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition   = FormStartPosition.CenterScreen;
        ClientSize      = new Size(488, 592);
        MaximizeBox = false; MinimizeBox = false;
        TopMost = true;

        int lx = 12, rw = 464, y = 12;

        AddL("Путь к хранилищу Obsidian (полный):", lx, y, rw); y += 20;
        txVault = AddT(s.VaultPath ?? "", lx, y, rw); y += 34;

        AddL("Папка для заметок:", lx, y, 222);
        AddL("Папка вложений:", lx + 232, y, 222); y += 20;
        txInbox  = AddT(s.Inbox ?? "", lx, y, 220);
        txAttach = AddT(s.Attachments ?? "Serv\\Attachments", lx + 232, y, 220); y += 34;

        AddL("Свойство даты:", lx, y, 200);
        AddL("Формат даты:", lx + 232, y, 200); y += 20;
        txDateProp = AddT(s.DatePropName ?? "date", lx, y, 200);
        txDate     = AddT(s.DateFormat ?? "yyyy-MM-dd", lx + 232, y, 200);
        AddLG("стандарт: date", lx + 210, y + 3, 18); y += 34;

        AddL("Свойства заметки:", lx, y, rw); y += 20;
        dgvProps = new DataGridView();
        dgvProps.Location = new Point(lx, y);
        dgvProps.Size     = new Size(rw, 114);
        dgvProps.RowHeadersVisible  = false;
        dgvProps.AllowUserToAddRows    = true;
        dgvProps.AllowUserToDeleteRows = true;
        dgvProps.AllowUserToResizeRows = false;
        dgvProps.ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.DisableResizing;
        dgvProps.ColumnHeadersHeight = 24;
        dgvProps.ScrollBars = ScrollBars.Vertical;
        dgvProps.Columns.Add(new DataGridViewTextBoxColumn { Name = "n", HeaderText = "Свойство", Width = 160 });
        dgvProps.Columns.Add(new DataGridViewTextBoxColumn { Name = "v", HeaderText = "Значение",
            AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill });
        foreach (string[] p in s.Props) if (p.Length >= 2) dgvProps.Rows.Add(p[0], p[1]);
        Controls.Add(dgvProps);
        AddLG("Редактируйте прямо в таблице. Delete на выбранной строке — удаление.", lx, y + 118, rw);
        y += 138;

        AddL("Шаблон Templater (оставьте пустым, если не нужен):", lx, y, rw); y += 20;
        txTmpl = AddT(s.TemplaterCmd ?? "", lx, y, rw);
        AddLG("напр.: templater-obsidian:Folder/Template.md", lx, y + 26, rw); y += 52;

        var grp = new GroupBox { Text = "Горячая клавиша", Location = new Point(lx, y), Size = new Size(rw, 64) };
        ckCtrl  = new CheckBox { Text = "Ctrl",  Location = new Point(10,  28), AutoSize = true, Checked = s.HotkeyCtrl  };
        ckAlt   = new CheckBox { Text = "Alt",   Location = new Point(78,  28), AutoSize = true, Checked = s.HotkeyAlt   };
        ckShift = new CheckBox { Text = "Shift", Location = new Point(142, 28), AutoSize = true, Checked = s.HotkeyShift };
        cbKey   = new ComboBox { Location = new Point(220, 24), Size = new Size(86, 24),
                      DropDownStyle = ComboBoxStyle.DropDownList };
        foreach (string kn in ClipSettings.KEY_NAMES) cbKey.Items.Add(kn);
        int sel = Array.IndexOf(ClipSettings.KEY_VKS, s.HotkeyVk);
        cbKey.SelectedIndex = (sel >= 0) ? sel : 7;
        grp.Controls.AddRange(new Control[] { ckCtrl, ckAlt, ckShift, cbKey });
        Controls.Add(grp); y += 76;

        var btnOk     = new Button { Text = "Сохранить", Location = new Point(rw - 176, y), Size = new Size(110, 30) };
        var btnCancel = new Button { Text = "Отмена",    Location = new Point(rw - 58,  y), Size = new Size(70,  30),
                            DialogResult = DialogResult.Cancel };
        Controls.Add(btnOk); Controls.Add(btnCancel);
        AcceptButton = btnOk; CancelButton = btnCancel;

        ClipSettings cap = s;
        btnOk.Click += delegate {
            if (string.IsNullOrWhiteSpace(txVault.Text)) {
                MessageBox.Show("Укажите путь к хранилищу.", "Ошибка",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            Result = new ClipSettings(cap.SettingsPath);
            Result.VaultPath    = txVault.Text.TrimEnd('\\', '/');
            Result.Inbox        = txInbox.Text.Trim();
            Result.Attachments  = txAttach.Text.Trim();
            Result.DatePropName = string.IsNullOrWhiteSpace(txDateProp.Text) ? "date" : txDateProp.Text.Trim();
            Result.DateFormat   = string.IsNullOrWhiteSpace(txDate.Text) ? "yyyy-MM-dd" : txDate.Text.Trim();
            Result.TemplaterCmd = txTmpl.Text.Trim();
            Result.HotkeyCtrl   = ckCtrl.Checked;
            Result.HotkeyAlt    = ckAlt.Checked;
            Result.HotkeyShift  = ckShift.Checked;
            Result.HotkeyVk     = (cbKey.SelectedIndex >= 0) ? ClipSettings.KEY_VKS[cbKey.SelectedIndex] : 0x77u;
            Result.Props        = new List<string[]>();
            foreach (DataGridViewRow row in dgvProps.Rows) {
                if (row.IsNewRow) continue;
                string pn = (row.Cells["n"].Value as string ?? "").Trim();
                string pv = (row.Cells["v"].Value as string ?? "").Trim();
                if (!string.IsNullOrEmpty(pn)) Result.Props.Add(new string[] { pn, pv });
            }
            DialogResult = DialogResult.OK;
        };
    }

    protected override void OnLoad(EventArgs e) { base.OnLoad(e); Activate(); }

    void AddL(string t, int x, int y, int w) {
        Controls.Add(new Label { Text = t, Location = new Point(x, y),
            Size = new Size(w, 18), AutoSize = false });
    }
    void AddLG(string t, int x, int y, int w) {
        Controls.Add(new Label { Text = t, Location = new Point(x, y),
            Size = new Size(w, 18), AutoSize = false, ForeColor = SystemColors.GrayText });
    }
    TextBox AddT(string text, int x, int y, int w) {
        var tb = new TextBox { Text = text, Location = new Point(x, y), Size = new Size(w, 22) };
        Controls.Add(tb); return tb;
    }
}

// ════════════════════════════════════════════════════════════
// Попап (закрывается через 10 сек)
// ════════════════════════════════════════════════════════════
public class NotePopup : Form {
    public NotePopup(string noteFile, string goUri) {
        int w = 330, h = 100;
        this.Text = "Obsidian Clip";
        this.FormBorderStyle = FormBorderStyle.FixedToolWindow;
        this.StartPosition   = FormStartPosition.Manual;
        this.Size            = new Size(w, h);
        this.TopMost         = true;
        this.ShowInTaskbar   = false;
        Rectangle wa  = Screen.PrimaryScreen.WorkingArea;
        this.Location = new Point(wa.Right - w - 12, wa.Bottom - h - 12);
        Label lbl = new Label { Text = noteFile, Location = new Point(8, 10),
                        Size = new Size(308, 20), AutoEllipsis = true };
        string uri = goUri;
        Button btnGo = new Button { Text = "Перейти в заметку",
                           Location = new Point(8, 40), Size = new Size(148, 26) };
        btnGo.Click += delegate { try { Process.Start(uri); } catch {} this.Close(); };
        Button btnX  = new Button { Text = "Закрыть",
                           Location = new Point(164, 40), Size = new Size(76, 26) };
        btnX.Click  += delegate { this.Close(); };
        this.Controls.AddRange(new Control[] { lbl, btnGo, btnX });
        Timer t = new Timer { Interval = 10000 };
        t.Tick += delegate { t.Stop(); t.Dispose(); this.Close(); };
        t.Start();
    }
}

// ════════════════════════════════════════════════════════════
// Основная форма
// ════════════════════════════════════════════════════════════
public class ClipForm : Form {

    [DllImport("user32.dll")] static extern bool  RegisterHotKey(IntPtr h, int id, uint mod, uint vk);
    [DllImport("user32.dll")] static extern bool  UnregisterHotKey(IntPtr h, int id);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint  GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);

    // Физическое состояние клавиш — для проверки, отпущены ли модификаторы хоткея
    [DllImport("user32.dll")] static extern short GetKeyState(int nVirtKey);

    // Низкоуровневая инъекция нажатий — надёжнее SendKeys в контексте хоткея
    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    const int    WM_HOTKEY        = 0x0312;
    const uint   KEYEVENTF_KEYUP  = 0x0002;
    const byte   VK_CONTROL       = 0x11;
    const byte   VK_C             = 0x43;
    const byte   VK_L             = 0x4C;
    const byte   VK_A             = 0x41;
    const byte   VK_ESCAPE        = 0x1B;

    readonly string[] BROWSERS = { "chrome","firefox","msedge","opera","brave","vivaldi" };
    ClipSettings settings;
    NotifyIcon   tray;
    bool         busy;
    bool         firstRun;

    // ── Вспомогательные методы для ввода ────────────────────
    bool IsKeyDown(int vk) { return (GetKeyState(vk) & 0x8000) != 0; }

    void KbDown(byte vk) { keybd_event(vk, 0, 0, UIntPtr.Zero); }
    void KbUp(byte vk)   { keybd_event(vk, 0, KEYEVENTF_KEYUP, UIntPtr.Zero); }

    void PressCtrl(byte vk) {
        KbDown(VK_CONTROL); KbDown(vk);
        System.Threading.Thread.Sleep(30);
        KbUp(vk); KbUp(VK_CONTROL);
        System.Threading.Thread.Sleep(30);
    }
    void PressKey(byte vk) {
        KbDown(vk);
        System.Threading.Thread.Sleep(30);
        KbUp(vk);
    }

    // Ждём, пока физические модификаторы будут отпущены (макс. 1.5 сек)
    void WaitModifiersUp() {
        for (int i = 0; i < 30; i++) {
            if (!IsKeyDown(0x10) && !IsKeyDown(0x11) && !IsKeyDown(0x12)) break;
            System.Threading.Thread.Sleep(50);
        }
        System.Threading.Thread.Sleep(80); // небольшой доп. зазор
    }

    public ClipForm(string settingsPath) {
        ShowInTaskbar = false;
        WindowState   = FormWindowState.Minimized;
        Opacity       = 0;

        settings = new ClipSettings(settingsPath);
        firstRun = !settings.Load();

        tray = new NotifyIcon { Icon = SystemIcons.Information, Visible = true };
        var menu = new ContextMenuStrip();
        menu.Items.Add("Настройки", null, delegate { OpenSettings(); });
        menu.Items.Add("-");
        menu.Items.Add("Выход", null, delegate { Application.Exit(); });
        tray.ContextMenuStrip = menu;

        Application.ThreadException += delegate(object sender,
                System.Threading.ThreadExceptionEventArgs e) {
            try { tray.ShowBalloonTip(6000, "Clip Error", e.Exception.Message, ToolTipIcon.Error); }
            catch {}
        };

        if (!firstRun) { RegisterHotkey(); UpdateTrayText(); }
        else tray.Text = "Obsidian Clip — настройка...";
    }

    protected override void OnLoad(EventArgs e) {
        base.OnLoad(e);
        if (!firstRun) return;
        try { OpenSettings(); }
        catch (Exception ex) {
            try { tray.ShowBalloonTip(8000, "Clip Setup Error", ex.Message, ToolTipIcon.Error); } catch {}
        }
        if (string.IsNullOrEmpty(settings.VaultPath)) { Application.Exit(); return; }
        RegisterHotkey(); UpdateTrayText(); firstRun = false;
    }

    void RegisterHotkey() {
        bool ok = RegisterHotKey(Handle, 1, settings.GetMod(), settings.HotkeyVk);
        if (!ok) try { tray.ShowBalloonTip(6000, "Obsidian Clip",
            "Не удалось зарегистрировать [" + settings.GetHotkeyDisplay() +
            "]. Сочетание занято другим приложением.", ToolTipIcon.Warning); } catch {}
    }

    void UpdateTrayText() {
        try { tray.Text = "Obsidian Clip  [" + settings.GetHotkeyDisplay() + "]"; } catch {}
    }

    void OpenSettings() {
        ClipSettings prev = settings;
        using (SettingsForm form = new SettingsForm(settings)) {
            if (form.ShowDialog() != DialogResult.OK || form.Result == null) return;
            bool hkChanged =
                form.Result.HotkeyCtrl  != prev.HotkeyCtrl  ||
                form.Result.HotkeyAlt   != prev.HotkeyAlt   ||
                form.Result.HotkeyShift != prev.HotkeyShift ||
                form.Result.HotkeyVk    != prev.HotkeyVk;
            settings = form.Result;
            settings.Save();
            if (hkChanged) { UnregisterHotKey(Handle, 1); RegisterHotkey(); }
            UpdateTrayText();
        }
    }

    bool IsBrowser(string p) {
        p = p.ToLower();
        foreach (var b in BROWSERS) if (p.Contains(b)) return true;
        return false;
    }

    string SafeName(string s) {
        if (string.IsNullOrWhiteSpace(s)) return "";
        int i = s.IndexOfAny(new[] { '\n', '\r' });
        if (i >= 0) s = s.Substring(0, i);
        foreach (char c in Path.GetInvalidFileNameChars()) s = s.Replace(c.ToString(), "");
        s = s.Trim();
        return s.Length > 80 ? s.Substring(0, 80) : s;
    }

    string SafeGetText() {
        for (int i = 0; i < 6; i++) {
            try { return Clipboard.GetText() ?? ""; } catch {}
            System.Threading.Thread.Sleep(80);
        }
        return "";
    }
    void SafeSetText(string t) {
        if (string.IsNullOrEmpty(t)) return;
        for (int i = 0; i < 5; i++) {
            try { Clipboard.SetText(t); return; } catch {}
            System.Threading.Thread.Sleep(50);
        }
    }
    void SafeClear() {
        for (int i = 0; i < 5; i++) {
            try { Clipboard.Clear(); return; } catch {}
            System.Threading.Thread.Sleep(50);
        }
    }
    void RestoreClipboard(string prev) {
        if (string.IsNullOrEmpty(prev)) SafeClear(); else SafeSetText(prev);
    }

    void DoClip(IntPtr hwnd) {
        if (busy) return;
        busy = true;
        try {
            if (string.IsNullOrEmpty(settings.VaultPath)) {
                try { tray.ShowBalloonTip(4000, "Obsidian Clip",
                    "Путь к хранилищу не задан. Откройте Настройки.", ToolTipIcon.Warning); } catch {}
                return;
            }

            // ── Ждём физического отпускания клавиш хоткея ───────────
            // Если Ctrl/Alt ещё удерживаются, SendInput послал бы
            // Ctrl+Alt+C вместо Ctrl+C, и буфер остался бы пустым.
            WaitModifiersUp();

            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            string proc = "";
            try { proc = Process.GetProcessById((int)pid).ProcessName; } catch {}
            var sb = new StringBuilder(512);
            GetWindowText(hwnd, sb, 512);
            string title = sb.ToString();

            string created  = DateTime.Now.ToString(settings.DateFormat ?? "yyyy-MM-dd");
            string ts       = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
            string prevText = SafeGetText();

            // ── 1. Копируем выделение ────────────────────────────────
            SafeClear();
            PressCtrl(VK_C);                        // keybd_event вместо SendKeys
            System.Threading.Thread.Sleep(500);     // ждём заполнения буфера
            string txt = SafeGetText();
            Image  img = null;
            try { img = Clipboard.GetImage(); } catch {}

            // ── 2. Source ────────────────────────────────────────────
            string source = "";
            if (IsBrowser(proc)) {
                try {
                    SafeClear();
                    PressCtrl(VK_L);                // фокус на адресную строку
                    System.Threading.Thread.Sleep(250);
                    PressCtrl(VK_A);                // выделить всё
                    System.Threading.Thread.Sleep(60);
                    PressCtrl(VK_C);                // копировать URL
                    System.Threading.Thread.Sleep(300);
                    source = SafeGetText();
                    PressKey(VK_ESCAPE);            // вернуться на страницу
                    System.Threading.Thread.Sleep(150);
                } catch {}
            } else if (proc.ToLower().Contains("telegram")) {
                source = "Telegram: " + title
                    .Replace(" \u2014 Telegram Desktop", "")
                    .Replace("Telegram Desktop", "").Trim();
            } else {
                source = title;
            }
            source = source.Replace("\r", "").Replace("\n", " ").Replace("\"", "'");

            // ── 3. Изображение ───────────────────────────────────────
            string imgEmbed = "";
            if (string.IsNullOrEmpty(txt) && img != null) {
                try {
                    string attDir = Path.Combine(settings.VaultPath,
                        settings.Attachments ?? "Attachments");
                    if (!Directory.Exists(attDir)) Directory.CreateDirectory(attDir);
                    string imgFile = "clip-" + ts + ".png";
                    img.Save(Path.Combine(attDir, imgFile), ImageFormat.Png);
                    imgEmbed = "![[" + (settings.Attachments ?? "Attachments").Replace('\\', '/')
                             + "/" + imgFile + "]]";
                } catch {}
            }

            if (string.IsNullOrEmpty(txt) && string.IsNullOrEmpty(imgEmbed)) {
                RestoreClipboard(prevText); return;
            }

            string name = SafeName(txt);
            if (string.IsNullOrEmpty(name)) name = "Clipped " + ts;

            string dir = string.IsNullOrEmpty(settings.Inbox)
                ? settings.VaultPath
                : Path.Combine(settings.VaultPath, settings.Inbox);
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

            string path = Path.Combine(dir, name + ".md");
            if (File.Exists(path)) path = Path.Combine(dir, name + " " + ts + ".md");

            string body      = string.IsNullOrEmpty(imgEmbed) ? txt : imgEmbed;
            string dateProp  = settings.DatePropName ?? "date";
            string extraProps = "";
            foreach (string[] p in settings.Props)
                if (p.Length >= 1 && !string.IsNullOrEmpty(p[0]))
                    extraProps += "\n" + p[0] + ": " + (p.Length > 1 ? p[1] : "");

            string note = "---\nsource: \"" + source + "\"\n" + dateProp + ": " + created
                        + extraProps + "\n---\n\n" + body + "\n";

            File.WriteAllText(path, note, Encoding.UTF8);
            RestoreClipboard(prevText);

            string vaultName = Path.GetFileName(settings.VaultPath.TrimEnd('\\', '/'));
            string relPath   = path.Substring(settings.VaultPath.Length)
                                   .TrimStart('\\', '/').Replace('\\', '/');

            if (!string.IsNullOrEmpty(settings.TemplaterCmd)) {
                try {
                    string advUri = "obsidian://advanced-uri?vault=" + Uri.EscapeDataString(vaultName)
                                  + "&filepath=" + Uri.EscapeDataString(relPath)
                                  + "&commandid=" + Uri.EscapeDataString(settings.TemplaterCmd);
                    Process.Start(advUri);
                } catch {}
            }

            try {
                string obsUri = "obsidian://open?vault=" + Uri.EscapeDataString(vaultName)
                              + "&file=" + Uri.EscapeDataString(relPath);
                new NotePopup(Path.GetFileName(path), obsUri).Show();
            } catch {
                try { tray.ShowBalloonTip(3000, "OK", Path.GetFileName(path), ToolTipIcon.Info); } catch {}
            }
        }
        catch (Exception ex) {
            try { tray.ShowBalloonTip(6000, "Clip Error", ex.Message, ToolTipIcon.Error); } catch {}
        }
        finally { busy = false; }
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == 1) {
            IntPtr hwnd = GetForegroundWindow();
            BeginInvoke(new Action(() => DoClip(hwnd)));
        }
        base.WndProc(ref m);
    }

    protected override void OnFormClosing(FormClosingEventArgs e) {
        UnregisterHotKey(Handle, 1);
        try { tray.Visible = false; tray.Dispose(); } catch {}
        base.OnFormClosing(e);
    }
}
'@ -ReferencedAssemblies "System.Windows.Forms","System.Drawing" -ErrorAction Stop
    Write-Log "Add-Type OK"
} catch {
    Write-Log "FATAL Add-Type: $_"
    [System.Windows.Forms.MessageBox]::Show(
        "Ошибка компиляции:`n`n" + $_.Exception.Message + "`n`nПодробности: $LogFile",
        "Obsidian Clip — Ошибка запуска")
    exit 1
}

Write-Log "Application.Run"
try {
    [System.Windows.Forms.Application]::Run((New-Object ClipForm($SettingsFile)))
} catch {
    Write-Log "FATAL Run: $_"
    [System.Windows.Forms.MessageBox]::Show("Ошибка запуска:`n`n" + $_.Exception.Message,
        "Obsidian Clip — Ошибка")
}
Write-Log "=== EXIT"
