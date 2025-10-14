# Installing Project Harvest on macOS 🍎

## For Mac Users: Running Unsigned Applications

**Project Harvest** is not code-signed with an Apple Developer certificate, which means macOS Gatekeeper will initially block the application. This is normal for indie/student games. Follow the instructions below to safely run the game.

---

## 📦 What You'll Download

You'll receive a `.zip` file containing `ProjectHarvest.app`

---

## 🔓 Method 1: Right-Click Method (Easiest)

This is the simplest method for most users:

1. **Download and extract** the `ProjectHarvest.zip` file
2. **Move** `ProjectHarvest.app` to your `Applications` folder (optional but recommended)
3. **Right-click** (or Control+Click) on `ProjectHarvest.app`
4. Select **"Open"** from the context menu
5. You'll see a dialog saying the app is from an unidentified developer
6. Click **"Open"** in the dialog
7. The game will launch and macOS will remember your choice for future launches

![Right-click to open unsigned app](https://support.apple.com/library/content/dam/edam/applecare/images/en_US/macos/Big-Sur/macos-big-sur-right-click-open.png)

---

## 🔓 Method 2: System Settings (macOS Ventura 13.0+)

If the right-click method doesn't work:

1. **Try to open** the app normally (it will be blocked)
2. Go to **System Settings** → **Privacy & Security**
3. Scroll down to the **Security** section
4. You'll see a message: *"ProjectHarvest.app was blocked from use because it is not from an identified developer"*
5. Click **"Open Anyway"**
6. Confirm by clicking **"Open"** in the dialog that appears

---

## 🔓 Method 3: Terminal Method (Advanced)

For users comfortable with Terminal:

1. **Open Terminal** (Applications → Utilities → Terminal)
2. **Navigate** to where you extracted the app:
   ```bash
   cd ~/Downloads
   ```
3. **Remove the quarantine attribute**:
   ```bash
   xattr -cr ProjectHarvest.app
   ```
4. **Make it executable** (if needed):
   ```bash
   chmod +x ProjectHarvest.app/Contents/MacOS/ProjectHarvest
   ```
5. **Launch the app** normally from Finder

---

## 🔓 Method 4: Disable Gatekeeper Temporarily (Not Recommended)

⚠️ **Use with caution** - only if other methods fail:

1. **Open Terminal**
2. **Disable Gatekeeper**:
   ```bash
   sudo spctl --master-disable
   ```
3. **Enter your password** when prompted
4. **Open the app** normally
5. **Re-enable Gatekeeper** immediately after:
   ```bash
   sudo spctl --master-enable
   ```

---

## ❓ Troubleshooting

### "The application is damaged and can't be opened"

This happens when macOS quarantines the download. Use **Method 3** (Terminal) to remove the quarantine flag:
```bash
xattr -cr ProjectHarvest.app
```

### Black Screen or Crash on Launch

1. Make sure you're running **macOS 10.12** or later (11.0+ for Apple Silicon Macs)
2. Try moving the app to `/Applications` instead of running from Downloads
3. Check that you have sufficient disk space and permissions

### Performance Issues

- Close other applications to free up RAM
- Make sure your Mac meets minimum requirements
- Try lowering graphics settings in-game (if available)

### The app opens but immediately closes

1. Right-click the app and select **"Show Package Contents"**
2. Navigate to `Contents/MacOS/`
3. Double-click the `ProjectHarvest` executable directly
4. Check Terminal for any error messages

---

## 🖥️ System Requirements

### Minimum:
- **OS:** macOS 10.12 (Sierra) or later
- **Processor:** Intel Core i5 or Apple Silicon M1
- **Memory:** 4 GB RAM
- **Graphics:** Metal-compatible GPU
- **Storage:** 2 GB available space

### Recommended:
- **OS:** macOS 11.0 (Big Sur) or later
- **Processor:** Intel Core i7 or Apple Silicon M1/M2
- **Memory:** 8 GB RAM
- **Graphics:** Metal 2-compatible GPU
- **Storage:** 4 GB available space

---

## 🛡️ Is This Safe?

**Yes!** This is a student/indie game project and is safe to run. The warnings you see are simply because:

1. The game is not signed with an Apple Developer certificate ($99/year)
2. It has not gone through Apple's notarization process

You can review the [source code on GitHub](https://github.com/yourusername/project_harvest) or scan the download with your antivirus if you have concerns.

---

## 📝 Why Isn't This Signed?

Apple requires developers to:
1. Pay $99/year for an Apple Developer account
2. Sign applications with their certificate
3. Submit apps for notarization

As a student/portfolio project, **Project Harvest** is distributed unsigned to keep it free and accessible. If you enjoy the game and want to support signed future releases, consider [supporting the developer](link-to-ko-fi-or-patreon).

---

## 🎮 Ready to Play?

Once you've successfully opened the game:

1. The first launch may take 30-60 seconds while macOS verifies the app
2. Future launches will be faster
3. Your save files are stored in `~/Library/Application Support/Godot/app_userdata/Project Harvest/`

**Enjoy your descent into the corn maze... if you dare.** 🌽🎃👻

---

## 💬 Need Help?

- **Issues?** Check the [main README](README.md) or open an issue on GitHub
- **Discord:** [Join our community](#) (if applicable)
- **Email:** [your-email@example.com]

---

**Made with Godot Engine 4.4 | Not affiliated with or endorsed by Apple Inc.**

