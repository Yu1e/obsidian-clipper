#Requires -Version 5.1
# OBSIDIAN QUICK CLIP
# Запуск: start.vbs
# Первый запуск → окно настроек. Далее: иконка в трее → Настройки.

$SettingsFile = Join-Path $PSScriptRoot "obsidian_clip.cfg"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Diagnostics;
using System.Windows.Forms;
using System.Runtime.InteropServices;

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

    public string SettingsPath { get; set; }
    public string VaultPath    { get; set; }
    public string Inbox        { get; set; }
    public string Attachments  { get; set; }
    public string DateFormat   { get; set; }
    public string PropName     { get; set; }
    public string PropValue    { get; set; }
    public string TemplaterCmd { get; set; }
    public bool   HotkeyCtrl  { get; set; }
    public bool   HotkeyAlt   { get; set; }
    public bool   HotkeyShift { get; set; }
    public uint   HotkeyVk    { get; set; }

    public ClipSettings(string path) {
        SettingsPath = path;
        Attachments  = "Serv\\Attachments";
        DateFormat   = "yyyy MM dd";
        PropName     = "auth";
        PropValue    = "other";
        HotkeyCtrl   = true;
        HotkeyAlt    = true;
        HotkeyShift  = false;
        HotkeyVk     = 0x77;
    }

    public bool Load() {
        if (!File.Exists(SettingsPath)) return false;
        try {
            foreach (string raw in File.ReadAllLines(SettingsPath, Encoding.UTF8)) {
                int eq = raw.IndexOf('=');
                if (eq < 0) continue;
                string k = raw.Substring(0, eq).Trim().ToLower();
                string v = raw.Substring(eq + 1);
                switch (k) {
                    case "vaultpath":    VaultPath    = v; break;
                    case "inbox":        Inbox        = v; break;
                    case "attachments":  Attachments  = v; break;
                    case "dateformat":   DateFormat   = v; break;
                    case "propname":     PropName     = v; break;
                    case "propvalue":    PropValue    = v; break;
                    case "templatercmd": TemplaterCmd = v; break;
                    case "hotkey_ctrl":  HotkeyCtrl  = (v == "true"); break;
                    case "hotkey_alt":   HotkeyAlt   = (v == "true"); break;
                    case "hotkey_shift": HotkeyShift = (v == "true"); break;
                    case "hotkey_vk": {
                        uint vk;
                        if (uint.TryParse(v, out vk)) HotkeyVk = vk;
                        break;
                    }
                }
            }
            return !string.IsNullOrEmpty(VaultPath);
        } catch { return false; }
    }

    public void Save() {
        File.WriteAllLines(SettingsPath, new string[] {
            "vaultpath="    + (VaultPath    ?? ""),
            "inbox="        + (Inbox        ?? ""),
            "attachments="  + (Attachments  ?? ""),
            "dateformat="   + (DateFormat   ?? "yyyy MM dd"),
            "propname="     + (PropName     ?? ""),
            "propvalue="    + (PropValue    ?? ""),
            "templatercmd=" + (TemplaterCmd ?? ""),
            "hotkey_ctrl="  + HotkeyCtrl.ToString().ToLower(),
            "hotkey_alt="   + HotkeyAlt.ToString().ToLower(),
            "hotkey_shift=" + HotkeyShift.ToString().ToLower(),
            "hotkey_vk="    + HotkeyVk.ToString()
        }, Encoding.UTF8);
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

    TextBox txVault, txInbox, txAttach, txDate, txPropName, txPropVal, txTmpl;
    CheckBox ckCtrl, ckAlt, ckShift;
    ComboBox cbKey;

    public SettingsForm(ClipSettings s) {
        Text            = "Настройки Obsidian Clip";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition   = FormStartPosition.CenterScreen;
        ClientSize      = new Size(484, 476);
        MaximizeBox     = false;
        MinimizeBox     = false;

        int lx = 12, rw = 460;

        // ── Vault path ──────────────────────────────────
        int y = 12;
        AddL("Путь к хранилищу Obsidian (полный):", lx, y, rw);
        y += 20;
        txVault = AddT(s.VaultPath ?? "", lx, y, rw);
        y += 34;

        // ── Inbox + Attachments ──────────────────────────
        AddL("Папка для заметок:", lx,       y, 220);
        AddL("Папка вложений:",   lx + 230,  y, 220);
        y += 20;
        txInbox  = AddT(s.Inbox       ?? "",       lx,      y, 218);
        txAttach = AddT(s.Attachments ?? "Serv\\Attachments", lx + 230, y, 218);
        y += 34;

        // ── Date format ──────────────────────────────────
        AddL("Формат даты:", lx, y, 200);
        AddLG("напр.: yyyy MM dd   dd.MM.yyyy", lx + 210, y + 2, 250);
        y += 20;
        txDate = AddT(s.DateFormat ?? "yyyy MM dd", lx, y, 200);
        y += 34;

        // ── Property ─────────────────────────────────────
        AddL("Свойство (имя):", lx,      y, 220);
        AddL("Значение:",       lx + 230, y, 220);
        y += 20;
        txPropName = AddT(s.PropName  ?? "auth",  lx,      y, 218);
        txPropVal  = AddT(s.PropValue ?? "other", lx + 230, y, 218);
        y += 34;

        // ── Templater command ────────────────────────────
        AddL("Шаблон Templater (оставьте пустым, если не нужен):", lx, y, rw);
        y += 20;
        txTmpl = AddT(s.TemplaterCmd ?? "", lx, y, rw);
        AddLG("напр.: templater-obsidian:Folder/Template.md", lx, y + 26, rw);
        y += 52;

        // ── Hotkey ───────────────────────────────────────
        var grp = new GroupBox {
            Text     = "Горячая клавиша",
            Location = new Point(lx, y),
            Size     = new Size(rw, 64)
        };
        ckCtrl  = new CheckBox { Text = "Ctrl",  Location = new Point(10,  28), AutoSize = true, Checked = s.HotkeyCtrl  };
        ckAlt   = new CheckBox { Text = "Alt",   Location = new Point(78,  28), AutoSize = true, Checked = s.HotkeyAlt   };
        ckShift = new CheckBox { Text = "Shift", Location = new Point(142, 28), AutoSize = true, Checked = s.HotkeyShift };
        cbKey   = new ComboBox {
            Location      = new Point(218, 24),
            Size          = new Size(86, 24),
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        foreach (string kn in ClipSettings.KEY_NAMES) cbKey.Items.Add(kn);
        int sel = Array.IndexOf(ClipSettings.KEY_VKS, s.HotkeyVk);
        cbKey.SelectedIndex = (sel >= 0) ? sel : 7;
        grp.Controls.AddRange(new Control[] { ckCtrl, ckAlt, ckShift, cbKey });
        Controls.Add(grp);
        y += 76;

        // ── Buttons ──────────────────────────────────────
        var btnOk = new Button {
            Text     = "Сохранить",
            Location = new Point(rw - 172, y),
            Size     = new Size(110, 30)
        };
        var btnCancel = new Button {
            Text         = "Отмена",
            Location     = new Point(rw - 54, y),
            Size         = new Size(66, 30),
            DialogResult = DialogResult.Cancel
        };
        Controls.Add(btnOk);
        Controls.Add(btnCancel);
        AcceptButton = btnOk;
        CancelButton = btnCancel;

        ClipSettings captured = s;
        btnOk.Click += delegate {
            if (string.IsNullOrWhiteSpace(txVault.Text)) {
                MessageBox.Show("Укажите путь к хранилищу.",
                    "Ошибка", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            Result              = new ClipSettings(captured.SettingsPath);
            Result.VaultPath    = txVault.Text.TrimEnd('\\', '/');
            Result.Inbox        = txInbox.Text.Trim();
            Result.Attachments  = txAttach.Text.Trim();
            Result.DateFormat   = string.IsNullOrWhiteSpace(txDate.Text) ? "yyyy MM dd" : txDate.Text.Trim();
            Result.PropName     = txPropName.Text.Trim();
            Result.PropValue    = txPropVal.Text.Trim();
            Result.TemplaterCmd = txTmpl.Text.Trim();
            Result.HotkeyCtrl   = ckCtrl.Checked;
            Result.HotkeyAlt    = ckAlt.Checked;
            Result.HotkeyShift  = ckShift.Checked;
            Result.HotkeyVk     = (cbKey.SelectedIndex >= 0)
                                ? ClipSettings.KEY_VKS[cbKey.SelectedIndex] : 0x77u;
            DialogResult = DialogResult.OK;
        };
    }

    void AddL(string t, int x, int y, int w) {
        Controls.Add(new Label { Text = t, Location = new Point(x, y), Size = new Size(w, 18), AutoSize = false });
    }
    void AddLG(string t, int x, int y, int w) {
        Controls.Add(new Label { Text = t, Location = new Point(x, y), Size = new Size(w, 18), AutoSize = false, ForeColor = SystemColors.GrayText });
    }
    TextBox AddT(string text, int x, int y, int w) {
        var tb = new TextBox { Text = text, Location = new Point(x, y), Size = new Size(w, 22) };
        Controls.Add(tb);
        return tb;
    }
}

// ════════════════════════════════════════════════════════════
// Попап
// ════════════════════════════════════════════════════════════
public class NotePopup : Form {
    public NotePopup(string noteFile, string goUri) {
        int w = 330, h = 100;
        this.Text            = "Obsidian Clip";
        this.FormBorderStyle = FormBorderStyle.FixedToolWindow;
        this.StartPosition   = FormStartPosition.Manual;
        this.Size            = new Size(w, h);
        this.TopMost         = true;
        this.ShowInTaskbar   = false;

        Rectangle wa = Screen.PrimaryScreen.WorkingArea;
        this.Location = new Point(wa.Right - w - 12, wa.Bottom - h - 12);

        Label lbl    = new Label();
        lbl.Text     = noteFile;
        lbl.Location = new Point(8, 10);
        lbl.Size     = new Size(308, 20);
        lbl.AutoEllipsis = true;
        this.Controls.Add(lbl);

        string uri   = goUri;
        Button btnGo = new Button();
        btnGo.Text   = "Перейти в заметку";
        btnGo.Location = new Point(8, 40);
        btnGo.Size   = new Size(148, 26);
        btnGo.Click += delegate { try { Process.Start(uri); } catch {} this.Close(); };
        this.Controls.Add(btnGo);

        Button btnX  = new Button();
        btnX.Text    = "Закрыть";
        btnX.Location = new Point(164, 40);
        btnX.Size    = new Size(76, 26);
        btnX.Click  += delegate { this.Close(); };
        this.Controls.Add(btnX);

        Timer t    = new Timer();
        t.Interval = 8000;
        t.Tick    += delegate { t.Stop(); t.Dispose(); this.Close(); };
        t.Start();
    }
}

// ════════════════════════════════════════════════════════════
// Основная форма
// ════════════════════════════════════════════════════════════
public class ClipForm : Form {

    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mod, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);

    const int WM_HOTKEY = 0x0312;

    readonly string[] BROWSERS = { "chrome","firefox","msedge","opera","brave","vivaldi" };
    ClipSettings settings;
    NotifyIcon   tray;
    bool         busy;
    bool         firstRun;

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

        Application.ThreadException += delegate(object sender, System.Threading.ThreadExceptionEventArgs e) {
            tray.ShowBalloonTip(6000, "Clip Error", e.Exception.Message, ToolTipIcon.Error);
        };

        if (!firstRun) {
            RegisterHotKey(Handle, 1, settings.GetMod(), settings.HotkeyVk);
            UpdateTrayText();
        } else {
            tray.Text = "Obsidian Clip — настройка...";
        }
    }

    protected override void OnLoad(EventArgs e) {
        base.OnLoad(e);
        if (firstRun) {
            OpenSettings();
            if (string.IsNullOrEmpty(settings.VaultPath)) {
                Application.Exit();
                return;
            }
            RegisterHotKey(Handle, 1, settings.GetMod(), settings.HotkeyVk);
            UpdateTrayText();
            firstRun = false;
        }
    }

    void UpdateTrayText() {
        tray.Text = "Obsidian Clip  [" + settings.GetHotkeyDisplay() + "]";
    }

    void OpenSettings() {
        ClipSettings before = settings;
        using (SettingsForm form = new SettingsForm(settings)) {
            if (form.ShowDialog() != DialogResult.OK || form.Result == null) return;
            bool hotkeyChanged =
                form.Result.HotkeyCtrl  != before.HotkeyCtrl  ||
                form.Result.HotkeyAlt   != before.HotkeyAlt   ||
                form.Result.HotkeyShift != before.HotkeyShift ||
                form.Result.HotkeyVk    != before.HotkeyVk;
            settings = form.Result;
            settings.Save();
            if (hotkeyChanged) {
                UnregisterHotKey(Handle, 1);
                RegisterHotKey(Handle, 1, settings.GetMod(), settings.HotkeyVk);
            }
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
        for (int i = 0; i < 5; i++) {
            try { return Clipboard.GetText() ?? ""; } catch {}
            System.Threading.Thread.Sleep(50);
        }
        return "";
    }
    void SafeSetText(string text) {
        if (string.IsNullOrEmpty(text)) return;
        for (int i = 0; i < 5; i++) {
            try { Clipboard.SetText(text); return; } catch {}
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
                tray.ShowBalloonTip(4000, "Obsidian Clip", "Путь к хранилищу не задан. Откройте Настройки.", ToolTipIcon.Warning);
                return;
            }

            System.Threading.Thread.Sleep(350);
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            string proc = "";
            try { proc = Process.GetProcessById((int)pid).ProcessName; } catch {}
            var sb = new StringBuilder(512);
            GetWindowText(hwnd, sb, 512);
            string title = sb.ToString();

            string created  = DateTime.Now.ToString(settings.DateFormat ?? "yyyy MM dd");
            string ts       = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
            string prevText = SafeGetText();

            // 1. Копируем выделение
            SafeClear();
            SendKeys.SendWait("^c");
            System.Threading.Thread.Sleep(400);

            string txt = SafeGetText();
            Image  img = null;
            try { img = Clipboard.GetImage(); } catch {}

            // 2. Source
            string source = "";
            if (IsBrowser(proc)) {
                try {
                    SafeClear();
                    SendKeys.SendWait("^l");
                    System.Threading.Thread.Sleep(250);
                    SendKeys.SendWait("^a");
                    System.Threading.Thread.Sleep(60);
                    SendKeys.SendWait("^c");
                    System.Threading.Thread.Sleep(250);
                    source = SafeGetText();
                    SendKeys.SendWait("{ESC}");
                    System.Threading.Thread.Sleep(150);
                } catch {}
            } else if (proc.ToLower().Contains("telegram")) {
                source = "Telegram: " + title
                    .Replace(" \u2014 Telegram Desktop", "")
                    .Replace("Telegram Desktop", "")
                    .Trim();
            } else {
                source = title;
            }
            source = source.Replace("\r", "").Replace("\n", " ").Replace("\"", "'");

            // 3. Изображение
            string imgEmbed = "";
            if (string.IsNullOrEmpty(txt) && img != null) {
                try {
                    string attDir = Path.Combine(settings.VaultPath, settings.Attachments ?? "Attachments");
                    if (!Directory.Exists(attDir)) Directory.CreateDirectory(attDir);
                    string imgFile = "clip-" + ts + ".png";
                    img.Save(Path.Combine(attDir, imgFile), ImageFormat.Png);
                    string attRel = (settings.Attachments ?? "Attachments").Replace('\\', '/');
                    imgEmbed = "![[" + attRel + "/" + imgFile + "]]";
                } catch {}
            }

            if (string.IsNullOrEmpty(txt) && string.IsNullOrEmpty(imgEmbed)) {
                RestoreClipboard(prevText);
                return;
            }

            string name = SafeName(txt);
            if (string.IsNullOrEmpty(name)) name = "Clipped " + ts;

            string dir = string.IsNullOrEmpty(settings.Inbox)
                ? settings.VaultPath
                : Path.Combine(settings.VaultPath, settings.Inbox);
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

            string path = Path.Combine(dir, name + ".md");
            if (File.Exists(path)) path = Path.Combine(dir, name + " " + ts + ".md");

            string body    = string.IsNullOrEmpty(imgEmbed) ? txt : imgEmbed;
            string prop    = (!string.IsNullOrEmpty(settings.PropName))
                           ? ("\n" + settings.PropName + ": " + (settings.PropValue ?? ""))
                           : "";
            string note    = "---\nsource: \"" + source + "\"\nсоздано: " + created
                           + prop + "\n---\n\n" + body + "\n";

            File.WriteAllText(path, note, Encoding.UTF8);
            RestoreClipboard(prevText);

            // 4. URI
            string vaultName = Path.GetFileName(settings.VaultPath.TrimEnd('\\', '/'));
            string relPath   = path.Substring(settings.VaultPath.Length).TrimStart('\\', '/').Replace('\\', '/');

            // 5. Применяем шаблон
            if (!string.IsNullOrEmpty(settings.TemplaterCmd)) {
                try {
                    string advUri = "obsidian://advanced-uri?vault=" + Uri.EscapeDataString(vaultName)
                                  + "&filepath=" + Uri.EscapeDataString(relPath)
                                  + "&commandid=" + Uri.EscapeDataString(settings.TemplaterCmd);
                    Process.Start(advUri);
                } catch {}
            }

            // 6. Попап
            try {
                string obsUri = "obsidian://open?vault=" + Uri.EscapeDataString(vaultName)
                              + "&file=" + Uri.EscapeDataString(relPath);
                new NotePopup(Path.GetFileName(path), obsUri).Show();
            } catch {
                tray.ShowBalloonTip(3000, "OK", Path.GetFileName(path), ToolTipIcon.Info);
            }
        }
        catch (Exception ex) {
            tray.ShowBalloonTip(6000, "Clip Error", ex.Message, ToolTipIcon.Error);
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
        tray.Visible = false;
        tray.Dispose();
        base.OnFormClosing(e);
    }
}
'@ -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"

try {
    [System.Windows.Forms.Application]::Run((New-Object ClipForm($SettingsFile)))
} catch {}
