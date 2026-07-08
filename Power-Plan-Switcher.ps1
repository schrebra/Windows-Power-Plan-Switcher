Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, System.Drawing

$CSharpCode = @"
using System;
using System.Windows.Forms;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows;
using System.Windows.Threading;

public class MacchiatoColorTable : ProfessionalColorTable
{
    private Color bg     = ColorTranslator.FromHtml("#363a4f");
    private Color border = ColorTranslator.FromHtml("#494d64");
    private Color hover  = ColorTranslator.FromHtml("#c6a0f6");

    public override Color MenuBorder                    { get { return border; } }
    public override Color ToolStripDropDownBackground   { get { return bg;     } }
    public override Color MenuItemSelected              { get { return hover;  } }
    public override Color MenuItemBorder                { get { return hover;  } }
    public override Color MenuStripGradientBegin        { get { return bg;     } }
    public override Color MenuStripGradientEnd          { get { return bg;     } }
    public override Color MenuItemSelectedGradientBegin { get { return hover;  } }
    public override Color MenuItemSelectedGradientEnd   { get { return hover;  } }
    public override Color MenuItemPressedGradientBegin  { get { return bg;     } }
    public override Color MenuItemPressedGradientEnd    { get { return bg;     } }
    public override Color SeparatorDark                 { get { return border; } }
    public override Color SeparatorLight                { get { return border; } }
}

public class MacchiatoRenderer : ToolStripProfessionalRenderer
{
    private Color normalFore = ColorTranslator.FromHtml("#cad3f5");
    private Color hoverFore  = ColorTranslator.FromHtml("#1e2030");

    public MacchiatoRenderer() : base(new MacchiatoColorTable()) { }

    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
    {
        if (e.Item.Selected || e.Item.Pressed)
            e.TextColor = hoverFore;
        else
            e.TextColor = normalFore;
        base.OnRenderItemText(e);
    }
}

public class TrayHelper
{
    private Window window;
    private NotifyIcon icon;

    public TrayHelper(Window w, NotifyIcon ni)
    {
        window = w;
        icon   = ni;
    }

    public void OnDoubleClick(object sender, EventArgs e)
    {
        window.Dispatcher.BeginInvoke(new Action(() =>
        {
            window.Show();
            window.WindowState = WindowState.Normal;
            window.Activate();
            icon.Visible = false;
        }));
    }

    public void OnTrayMenuClick(object sender, EventArgs e)
    {
        var item = sender as ToolStripMenuItem;
        if (item == null) return;

        string guid = null;
        string tag  = (item.Tag ?? "").ToString();

        switch (tag)
        {
            case "saver": guid = "a1841308-3541-4fab-bc81-f71556f20b4a"; break;
            case "balanced": guid = "381b4222-f694-41f0-9685-ff5bb260df2e"; break;
            case "high": guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; break;
            case "exit":
                window.Dispatcher.BeginInvoke(new Action(() =>
                {
                    icon.Visible = false;
                    icon.Dispose();
                    window.Close();
                }));
                return;
        }

        if (guid != null)
        {
            var psi = new System.Diagnostics.ProcessStartInfo("powercfg", "/setactive " + guid);
            psi.CreateNoWindow = true;
            psi.UseShellExecute = false;
            var proc = System.Diagnostics.Process.Start(psi);
            if (proc != null) proc.WaitForExit();

            // Fire a custom event the PS side can listen to
            if (PlanChanged != null) PlanChanged(this, EventArgs.Empty);
        }
    }

    public event EventHandler PlanChanged;
}
"@

Add-Type -TypeDefinition $CSharpCode `
    -ReferencedAssemblies "PresentationFramework","System.Windows.Forms",
                          "WindowsBase","PresentationCore","System.Xaml",
                          "System.Drawing","System"

# -----------------------------------------------------------------------
# XAML
# -----------------------------------------------------------------------
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Power Plan Switcher" Height="416" Width="420"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="Transparent" AllowsTransparency="True" WindowStyle="None">

    <Window.Resources>
        <Storyboard x:Key="FadeIn">
            <DoubleAnimation Storyboard.TargetProperty="Opacity"
                             From="0" To="1" Duration="0:0:0.5">
                <DoubleAnimation.EasingFunction>
                    <CubicEase EasingMode="EaseOut"/>
                </DoubleAnimation.EasingFunction>
            </DoubleAnimation>
        </Storyboard>

        <Style x:Key="PlanButton" TargetType="Button">
            <Setter Property="FontSize"    Value="14"/>
            <Setter Property="FontFamily"  Value="Segoe UI Variable, Segoe UI"/>
            <Setter Property="FontWeight"  Value="SemiBold"/>
            <Setter Property="Height"      Value="48"/>
            <Setter Property="Margin"      Value="0,5,0,5"/>
            <Setter Property="Cursor"      Value="Hand"/>
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd"
                                Background="{TemplateBinding Background}"
                                CornerRadius="0"
                                BorderBrush="#3b3f58"
                                BorderThickness="1"
                                Padding="18,0">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <Ellipse x:Name="dot" Grid.Column="0"
                                         Width="10" Height="10"
                                         Fill="{TemplateBinding Foreground}"
                                         Opacity="0.7"
                                         VerticalAlignment="Center"
                                         Margin="0,0,14,0"/>
                                <ContentPresenter Grid.Column="1"
                                                  VerticalAlignment="Center"
                                                  HorizontalAlignment="Left"/>
                                <TextBlock Grid.Column="2" Text="›"
                                           FontSize="22" Foreground="#5b6078"
                                           VerticalAlignment="Center"
                                           Opacity="0.5" x:Name="chevron"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#2a2d3d"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#c6a0f6"/>
                                <Setter TargetName="dot" Property="Opacity" Value="1"/>
                                <Setter TargetName="chevron" Property="Opacity" Value="1"/>
                                <Setter TargetName="chevron" Property="Foreground" Value="#c6a0f6"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#1e2030"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#c6a0f6"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border Background="#1e2030" BorderBrush="#2a2d3d"
            BorderThickness="1.5" CornerRadius="0">
        <Border.Effect>
            <DropShadowEffect Color="#000000" BlurRadius="40"
                              ShadowDepth="0" Opacity="0.55"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- TITLE BAR -->
            <Border Grid.Row="0" Background="Transparent"
                    Padding="24,14,16,8" x:Name="TitleBar">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Orientation="Horizontal"
                                VerticalAlignment="Center">
                        <TextBlock Text="⚡" FontSize="18" Margin="0,0,10,0"
                                   Foreground="#cad3f5" VerticalAlignment="Center"/>
                        <TextBlock Text="Power Plan Switcher"
                                   Foreground="#cad3f5" FontSize="14"
                                   FontFamily="Segoe UI Variable, Segoe UI"
                                   FontWeight="SemiBold"
                                   VerticalAlignment="Center"/>
                    </StackPanel>
                    <Button Name="BtnMinimize" Grid.Column="1"
                            Width="34" Height="34" Margin="4,0"
                            Background="Transparent" BorderThickness="0"
                            Cursor="Hand" ToolTip="Minimize to tray">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="bg" Background="Transparent"
                                        CornerRadius="0" Width="34" Height="34">
                                    <TextBlock Text="—" Foreground="#6e738d"
                                               FontSize="13" FontWeight="Bold"
                                               HorizontalAlignment="Center"
                                               VerticalAlignment="Center" x:Name="ico"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="bg" Property="Background" Value="#363a4f"/>
                                        <Setter TargetName="ico" Property="Foreground" Value="#cad3f5"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                    <Button Name="BtnClose" Grid.Column="2"
                            Width="34" Height="34"
                            Background="Transparent" BorderThickness="0"
                            Cursor="Hand" ToolTip="Close">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="bg" Background="Transparent"
                                        CornerRadius="0" Width="34" Height="34">
                                    <TextBlock Text="✕" Foreground="#6e738d"
                                               FontSize="12"
                                               HorizontalAlignment="Center"
                                               VerticalAlignment="Center" x:Name="ico"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="bg" Property="Background" Value="#ed8796"/>
                                        <Setter TargetName="ico" Property="Foreground" Value="#1e2030"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </Grid>
            </Border>

            <!-- CONTENT -->
            <StackPanel Grid.Row="1" Margin="28,2,28,6" VerticalAlignment="Top">
                <TextBlock Text="Select Power Plan"
                           Foreground="#c6a0f6" FontSize="20"
                           FontFamily="Segoe UI Variable, Segoe UI"
                           FontWeight="Bold" Margin="0,4,0,3"/>
                <TextBlock Text="Choose a profile to optimise performance and battery life."
                           Foreground="#6e738d" FontSize="12"
                           FontFamily="Segoe UI Variable, Segoe UI"
                           TextWrapping="Wrap" Margin="0,0,0,16"/>
                <Button Name="BtnPowerSaver" Content="Power Saver"
                        Style="{StaticResource PlanButton}"
                        Background="#24273a" Foreground="#a6da95"/>
                <Button Name="BtnBalanced" Content="Balanced"
                        Style="{StaticResource PlanButton}"
                        Background="#24273a" Foreground="#8aadf4"/>
                <Button Name="BtnHighPerf" Content="High Performance"
                        Style="{StaticResource PlanButton}"
                        Background="#24273a" Foreground="#ed8796"/>
            </StackPanel>

            <!-- FOOTER -->
            <Border Grid.Row="2" Background="#181926" Padding="28,12,28,14">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Ellipse Name="StatusDot" Grid.Column="0"
                             Width="8" Height="8" Fill="#a6da95"
                             VerticalAlignment="Center" Margin="0,0,10,0"/>
                    <TextBlock Name="TxtStatus" Grid.Column="1"
                               Text="Checking..." Foreground="#8087a2"
                               FontSize="12.5"
                               FontFamily="Segoe UI Variable, Segoe UI"
                               FontWeight="Medium" VerticalAlignment="Center"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
"@

$reader        = New-Object System.Xml.XmlNodeReader $xaml
$window        = [Windows.Markup.XamlReader]::Load($reader)

$btnPowerSaver = $window.FindName("BtnPowerSaver")
$btnBalanced   = $window.FindName("BtnBalanced")
$btnHighPerf   = $window.FindName("BtnHighPerf")
$txtStatus     = $window.FindName("TxtStatus")
$statusDot     = $window.FindName("StatusDot")
$btnMinimize   = $window.FindName("BtnMinimize")
$btnClose      = $window.FindName("BtnClose")
$titleBar      = $window.FindName("TitleBar")

# -----------------------------------------------------------------------
# Title bar drag
# -----------------------------------------------------------------------
$titleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
$btnMinimize.Add_Click({ $window.WindowState = [System.Windows.WindowState]::Minimized })
$btnClose.Add_Click({ $window.Close() })

# Fade-in
$window.Add_ContentRendered({
    $sb = $window.FindResource("FadeIn")
    $window.BeginStoryboard($sb)
})
$window.Opacity = 0

# -----------------------------------------------------------------------
# Tray icon
# -----------------------------------------------------------------------
$notifyIcon         = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Visible = $true

$trayMenu                 = New-Object System.Windows.Forms.ContextMenuStrip
$trayMenu.Renderer        = New-Object MacchiatoRenderer
$trayMenu.ShowImageMargin = $false
$trayMenu.BackColor       = [System.Drawing.ColorTranslator]::FromHtml("#363a4f")
$trayMenu.ForeColor       = [System.Drawing.ColorTranslator]::FromHtml("#cad3f5")
$trayMenu.Font            = New-Object System.Drawing.Font("Segoe UI", 10)

$ctxSave = New-Object System.Windows.Forms.ToolStripMenuItem("Power Saver")
$ctxBal  = New-Object System.Windows.Forms.ToolStripMenuItem("Balanced")
$ctxHigh = New-Object System.Windows.Forms.ToolStripMenuItem("High Performance")
$ctxSep  = New-Object System.Windows.Forms.ToolStripSeparator
$ctxExit = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")

$ctxSave.Tag = "saver"
$ctxBal.Tag  = "balanced"
$ctxHigh.Tag = "high"
$ctxExit.Tag = "exit"

foreach ($item in @($ctxSave,$ctxBal,$ctxHigh,$ctxExit)) {
    $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#363a4f")
    $item.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#cad3f5")
}

[void]$trayMenu.Items.Add($ctxSave)
[void]$trayMenu.Items.Add($ctxBal)
[void]$trayMenu.Items.Add($ctxHigh)
[void]$trayMenu.Items.Add($ctxSep)
[void]$trayMenu.Items.Add($ctxExit)

$notifyIcon.ContextMenuStrip = $trayMenu

# -----------------------------------------------------------------------
# C# TrayHelper — handles all tray events safely without PS pipeline
# -----------------------------------------------------------------------
$trayHelper = New-Object TrayHelper $window, $notifyIcon

# Wire double-click via C# delegate (avoids PS pipeline crash)
$notifyIcon.add_DoubleClick(
    [System.Delegate]::CreateDelegate(
        [System.EventHandler], $trayHelper, "OnDoubleClick")
)

# Wire all menu items via C# delegate
$clickDelegate = [System.Delegate]::CreateDelegate(
    [System.EventHandler], $trayHelper, "OnTrayMenuClick")

$ctxSave.add_Click($clickDelegate)
$ctxBal.add_Click($clickDelegate)
$ctxHigh.add_Click($clickDelegate)
$ctxExit.add_Click($clickDelegate)

# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------
function Update-TrayIcon {
    param([string]$hexColor)
    $bmp             = New-Object System.Drawing.Bitmap(32,32)
    $g               = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush           = New-Object System.Drawing.SolidBrush(
                           [System.Drawing.ColorTranslator]::FromHtml($hexColor))
    $g.FillEllipse($brush, 2, 2, 28, 28)
    $g.Dispose()
    $notifyIcon.Icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $bmp.Dispose()
}

function Set-ActiveGlow {
    param($activeButton, [string]$hexColor)
    $btnPowerSaver.Effect = $null
    $btnBalanced.Effect   = $null
    $btnHighPerf.Effect   = $null

    if ($activeButton) {
        $color = [System.Windows.Media.Color]::FromRgb(
            [Convert]::ToByte($hexColor.Substring(1,2), 16),
            [Convert]::ToByte($hexColor.Substring(3,2), 16),
            [Convert]::ToByte($hexColor.Substring(5,2), 16))
        $fx             = New-Object System.Windows.Media.Effects.DropShadowEffect
        $fx.Color       = $color
        $fx.ShadowDepth = 0
        $fx.BlurRadius  = 24
        $fx.Opacity     = 0.5
        $activeButton.Effect = $fx
    }
}

function Update-StatusDot {
    param([string]$hexColor)
    $statusDot.Fill = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(
            [Convert]::ToByte($hexColor.Substring(1,2), 16),
            [Convert]::ToByte($hexColor.Substring(3,2), 16),
            [Convert]::ToByte($hexColor.Substring(5,2), 16))
    )
}

function Update-Status {
    $current   = powercfg /getactivescheme
    $cleanName = if ($current -match "\((.*?)\)") { $matches[1] } else { "Unknown" }

    $txtStatus.Text = "Active  ·  $cleanName"

    switch ($cleanName) {
        "Power Saver"      {
            Set-ActiveGlow $btnPowerSaver "#a6da95"
            Update-TrayIcon "#a6da95"
            Update-StatusDot "#a6da95"
        }
        "Balanced"         {
            Set-ActiveGlow $btnBalanced "#8aadf4"
            Update-TrayIcon "#8aadf4"
            Update-StatusDot "#8aadf4"
        }
        "High Performance" {
            Set-ActiveGlow $btnHighPerf "#ed8796"
            Update-TrayIcon "#ed8796"
            Update-StatusDot "#ed8796"
        }
    }

    $notifyIcon.Text = "Active Plan: $cleanName"
}

function Switch-Plan {
    param([string]$guid, [string]$name)
    powercfg /setactive $guid
    if ($LASTEXITCODE -eq 0) {
        Update-Status
    } else {
        $txtStatus.Text = "Failed to switch to $name."
        [System.Windows.Forms.MessageBox]::Show("Failed to switch to $name.", "Error", 0, 16)
    }
}

# -----------------------------------------------------------------------
# When C# TrayHelper switches a plan, refresh the WPF UI
# -----------------------------------------------------------------------
$trayHelper.add_PlanChanged({
    $window.Dispatcher.BeginInvoke([System.Action]{
        Update-Status
    })
})

# -----------------------------------------------------------------------
# WPF button events
# -----------------------------------------------------------------------
$btnPowerSaver.Add_Click({ Switch-Plan "a1841308-3541-4fab-bc81-f71556f20b4a" "Power Saver"       })
$btnBalanced.Add_Click(  { Switch-Plan "381b4222-f694-41f0-9685-ff5bb260df2e" "Balanced"          })
$btnHighPerf.Add_Click(  { Switch-Plan "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" "High Performance" })

# -----------------------------------------------------------------------
# Minimize to tray
# -----------------------------------------------------------------------
$window.Add_StateChanged({
    if ($window.WindowState -eq [System.Windows.WindowState]::Minimized) {
        $window.Hide()
        $notifyIcon.Visible = $true
    }
})

# -----------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------
$window.Add_Closing({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
})

# -----------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------
Update-Status
$window.Show()
[System.Windows.Forms.Application]::Run()
