<div align="center">

# Captive Portal Chat Plugin for PHPNuxBill

[![StandWithPalestine](https://raw.githubusercontent.com/Safouene1/support-palestine-banner/master/StandWithPalestine.svg)](https://github.com/Safouene1/support-palestine-banner/blob/master/Markdown-pages/Support.md)

[![Platform](https://img.shields.io/badge/platform-PHPNuxBill-3B82F6?style=flat-square)](#)
[![PHP](https://img.shields.io/badge/PHP-8.2%2B-777BB4?style=flat-square&logo=php&logoColor=white)](#)
[![MikroTik](https://img.shields.io/badge/MikroTik-Hotspot-293239?style=flat-square)](#)
[![LICENSE](https://img.shields.io/badge/LICENSE-MIT-FF6655?style=flat-square)](#)

Live customer support chat widget for **MikroTik Hotspot captive portal** pages (`login.html`, `logout.html`, `status.html`) integrated directly into PHPNuxBill.

</div>

## Features

- **Captive Portal Widget**: Lightweight embed snippet for MikroTik Hotspot `login.html`, `logout.html`, and `status.html`.
- **Admin Inbox & Dashboard**: Real-time polling, unread navbar notification bell, conversation assignment, tags, and close reasons.
- **Productivity Tools**: Canned replies, business hours / away message, and CSV/PDF conversation export.
- **Spam Protection**: Built-in captcha, rate-limit cooldown, IP/MAC blocking, and spam log.

## Install

### Option 1: Marketplace / Plugin Manager (Recommended)
1. Open **Marketplace → Plugins** (or **Plugin Manager**) in PHPNuxBill Admin.
2. Install **Captive Portal Chat** from the store, or upload the `captivePortalChat` `.zip` / GitHub URL (`https://github.com/mhmd3010/captiveportalchat`).
3. Activate the plugin.

### Option 2: Manual
Copy the `captivePortalChat` folder into `system/plugin/`:

```bash
cp -r captivePortalChat /path/to/phpnuxbill/system/plugin/
```

## Setup

1. Open **Captive Portal Chat** in the admin sidebar.
2. Go to **Settings**, configure your widget title, welcome message, business hours, and spam limits.
3. Copy the generated widget `<script>` snippet into your MikroTik Hotspot `login.html` / `status.html` / `logout.html`.

## Support

Need help or want to support development?

[![Telegram](https://img.shields.io/badge/Telegram-Mahmud-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/mhmd_3010)
