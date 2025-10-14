# macOS Distribution Guide for Project Harvest

## Files Created for Mac Users

I've created several files to help your Mac users run the unsigned game. Here's what each file is for and how to use them:

---

## 📄 File Overview

### 1. `MACOS_INSTALL.md` (Comprehensive Guide)
**Purpose:** Complete installation instructions with troubleshooting  
**Where to use:**
- Include in your GitHub repository
- Link from itch.io/game page
- Reference in Steam/other platform descriptions

**Contents:**
- 4 different methods to bypass Gatekeeper
- Detailed troubleshooting section
- System requirements
- Safety explanation

---

### 2. `MAC_USERS_READ_THIS.txt` (Quick Reference)
**Purpose:** Short, text-only instructions users see immediately  
**Where to use:**
- **Include this file in your Mac .zip distribution**
- Place it in the root next to `ProjectHarvest.app`
- Name makes it obvious users should read it first

**When to include:**
```
ProjectHarvest.zip
├── ProjectHarvest.app/
├── MAC_USERS_READ_THIS.txt  ← Include this!
└── MACOS_INSTALL.md  ← Optionally include this too
```

---

### 3. `macos_instructions.html` (Web-Friendly)
**Purpose:** Styled HTML version for hosting on websites  
**Where to use:**
- Upload to itch.io as part of game description
- Host on your personal website
- Link from download pages
- Embed in game documentation sites

**How to use on itch.io:**
1. Go to your game's "Edit game" page
2. Scroll to the "Downloads" section
3. Add a devlog or update that includes the HTML content
4. Or link to the raw GitHub file

---

## 🚀 Distribution Checklist

### For GitHub Releases:
```
✓ MACOS_INSTALL.md (in repo root)
✓ MAC_USERS_READ_THIS.txt (in .zip with app)
✓ Updated README.md (already done)
✓ Link to MACOS_INSTALL.md in release notes
```

### For itch.io:
```
✓ Upload ProjectHarvest.zip with MAC_USERS_READ_THIS.txt included
✓ Add warning text to download page description
✓ Paste macos_instructions.html content into description or devlog
✓ Set minimum OS version to 10.12
```

### For Direct Distribution:
```
✓ Include MAC_USERS_READ_THIS.txt in the .zip
✓ Send link to MACOS_INSTALL.md to users
✓ Consider creating a one-page website with macos_instructions.html
```

---

## ⚠️ Important Notes About Your Export

Your current export configuration (`export_presets.cfg` line 82):
```
export_path="../ProjectHarvest.zip"
```

This exports as a `.zip` file, which is correct for macOS distribution.

### Settings to Verify:
- ✅ Universal binary (Intel + Apple Silicon) - Currently enabled
- ✅ Console wrapper enabled (line 97) - Good for debugging
- ❌ Code signing disabled - This is expected (not signed)
- ❌ Notarization disabled - This is expected

---

## 📝 Sample itch.io Description Text

Here's text you can paste into your itch.io game description:

```markdown
## ⚠️ Important for macOS Users

**This game is not code-signed.** macOS will block it by default with a security warning.

**This is normal for indie games and the download is safe.**

### Quick Fix (30 seconds):
1. Right-click (Control+Click) on the .app file
2. Select "Open"
3. Click "Open" when warned
4. Done! ✓

**Need help?** See the detailed [macOS Installation Guide](link-to-your-guide)

### System Requirements:
- macOS 10.12+ (11.0+ for M1/M2 Macs)
- 4GB RAM minimum
- Metal-compatible graphics
```

---

## 🔍 Testing Checklist

Before distributing, test on:
- [ ] Intel Mac running latest macOS
- [ ] Apple Silicon Mac (M1/M2)
- [ ] Older macOS version (10.12-11.0)
- [ ] Fresh Mac without dev tools installed

Test scenarios:
- [ ] Double-clicking the app (should be blocked)
- [ ] Right-click → Open (should work)
- [ ] Terminal xattr command (should work)
- [ ] System Settings → Open Anyway (should work)

---

## 💡 Future Options

### If You Get an Apple Developer Account:
1. Sign the app:
   ```bash
   codesign --force --deep --sign "Developer ID Application: Your Name" ProjectHarvest.app
   ```
2. Notarize with Apple
3. Staple the ticket
4. Users can open it normally

### Alternatives:
- **Steam:** They handle code signing for Mac builds
- **Epic Games Store:** Similar to Steam
- **itch.io:** Users are familiar with unsigned games

---

## 📧 Support Responses

When users report "can't open" issues, respond with:

> Hi! This is expected on macOS. The game isn't code-signed (Apple charges $99/year for that), but it's completely safe.
> 
> Quick fix:
> 1. Right-click the app
> 2. Click "Open"
> 3. Click "Open" again when warned
> 
> Full instructions: [link to MACOS_INSTALL.md]

---

## Summary

You now have:
1. ✅ Comprehensive documentation (MACOS_INSTALL.md)
2. ✅ Quick reference for users (MAC_USERS_READ_THIS.txt)
3. ✅ Web-friendly guide (macos_instructions.html)
4. ✅ Updated README with Mac instructions

**Next steps:**
1. Include `MAC_USERS_READ_THIS.txt` in your next Mac build .zip
2. Link to `MACOS_INSTALL.md` on your itch.io/download pages
3. Test on a real Mac to verify everything works
4. Update the GitHub links in the HTML/MD files with your actual repo URL

---

*Remember to update any placeholder links (GitHub URLs, support emails, etc.) in the files before distribution!*

