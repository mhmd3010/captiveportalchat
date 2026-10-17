# Captive Portal Chat

Live chat between MikroTik hotspot customers and ISP support staff, built as a plugin for [PHPNuxBill](https://github.com/hotspotbilling/phpnuxbill).

Customers tap a chat bubble on the captive portal (login / logout / status page), admins reply from the billing panel and get notified by a navbar bell. No external service, no WebSocket — plain AJAX polling.

## Features

- **Hotspot widget** — injectable snippet for MikroTik hotspot pages, auto-detects `$(mac)`, `$(ip)`, `$(username)`, `$(hostname)`
- **Admin inbox** — two-pane workbench: conversation list with filters (status, router, tag, agent, spam, full-text search) + thread view
- **Navbar bell** — unread counter, dropdown of latest messages, browser notifications + sound
- **Dashboard** — stat cards, 14-day activity chart (ApexCharts), latest chats with quick actions, agent workload
- **Workflow** — open/close with reason, agent assignment, tags, canned replies
- **Spam protection** — honeypot field, math captcha, link stripping, rate limits, auto IP/MAC block, manual blocklist, rejection log
- **Export** — CSV and PDF (uses the bundled mPDF)
- **Support hours** — online/offline state with away message
- **Roles** — restricted to SuperAdmin and Admin
- All timestamps rendered server-side with PHPNuxBill timezone + date format settings

## Requirements

- PHPNuxBill (tested on 5.x)
- MikroTik hotspot with editable portal pages
- Internet access in the admin browser for the ApexCharts CDN (dashboard chart only)

## Installation

1. Copy the plugin files into your PHPNuxBill installation:

```
system/plugin/captivePortalChat.php
system/plugin/ui/cpchat/
```

2. Open **Captive Portal Chat** in the admin sidebar. Tables are created automatically.
3. In **Settings → Installation**, click *Install* to add the navbar bell.
4. On the same tab, copy the widget snippet into your hotspot `login.html` (and `logout.html` / `status.html` if wanted) before `</body>`.
5. Enable the chat in **Settings → General**.

## Update

Replace the files above with the new versions. Existing conversations and settings are kept.

## File layout

```
system/plugin/captivePortalChat.php     all PHP: pages, APIs, schema, spam logic
system/plugin/ui/cpchat/
  dashboard.tpl   admin dashboard
  inbox.tpl       admin chat workbench (+ admin JS)
  settings.tpl    settings, spam, canned replies, blocklist
  cpchat.css      styles for components the theme does not provide
  navbar.js       admin navbar bell
  widget.js       customer-side widget (self-injected styles)
```

## API endpoints

Public (used by the hotspot widget): `cpchatStart`, `cpchatSend`, `cpchatPoll`, `cpchatClose`, `cpchatCaptcha`, `cpchatWidgetJs`

Admin (used by inbox/dashboard): `cpchatAdminThreads`, `cpchatAdminThread`, `cpchatAdminSend`, `cpchatAdminStatus`, `cpchatAdminClose`, `cpchatAdminAssign`, `cpchatAdminTags`, `cpchatAdminSpam`, `cpchatAdminBlock`, `cpchatAdminPoll`, `cpchatAdminCount`, `cpchatAdminDelete`, `cpchatExportCsv`, `cpchatExportPdf`

## License

Same license as PHPNuxBill.
