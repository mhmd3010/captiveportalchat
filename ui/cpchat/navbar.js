/*!
 * Captive Portal Chat - admin navbar notifier for PHPNuxBill
 * Injected into the admin navbar by the plugin (see settings page).
 * Vanilla JS, polls the plugin endpoints and raises in-page + browser notifications.
 */
(function () {
    'use strict';

    var cfg = window.CPCHAT_NAVBAR || {};
    if (!cfg.enabled) {
        return;
    }
    var urls = cfg.urls || {};
    var interval = (parseInt(cfg.poll, 10) || 15) * 1000;
    var storeKey = 'cpchat_admin_last_id';

    var last = 0;
    var firstRun = true;
    var bell = null;
    var badge = null;
    var menu = null;
    var unreadTotal = 0;
    var openChats = 0;
    var items = [];
    var originalTitle = document.title;
    var flashTimer = null;

    function lsGet(k) {
        try {
            return window.localStorage.getItem(k);
        } catch (e) {
            return null;
        }
    }

    function lsSet(k, v) {
        try {
            window.localStorage.setItem(k, v);
        } catch (e) { }
    }

    function get(id, done) {
        var xhr = new XMLHttpRequest();
        xhr.open('GET', id, true);
        xhr.timeout = 20000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) {
                return;
            }
            if (xhr.status === 0) {
                done(null);
                return;
            }
            var json = null;
            try {
                json = JSON.parse(xhr.responseText);
            } catch (e) {
                json = null;
            }
            done(json);
        };
        xhr.ontimeout = function () { done(null); };
        xhr.onerror = function () { done(null); };
        xhr.send();
    }

    function withParam(url, key, value) {
        return url + (url.indexOf('?') === -1 ? '?' : '&') + encodeURIComponent(key) + '=' + encodeURIComponent(value);
    }

    function escapeText(t) {
        var d = document.createElement('div');
        d.appendChild(document.createTextNode(String(t === null || t === undefined ? '' : t)));
        return d.innerHTML;
    }

    /* ---------------- markup ---------------- */

    /* inline SVG icons: the admin theme ships Font Awesome 4.3, but a custom
     * theme may not load it at all, so the bell never depends on icon fonts */
    var ICON_BELL = '<svg class="cpchat-ico" viewBox="0 0 24 24" width="17" height="17" fill="none"'
        + ' stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        + '<path d="M12 3.2a5.3 5.3 0 0 0-5.3 5.3v3.6L5.1 15.6h13.8l-1.6-3.5V8.5A5.3 5.3 0 0 0 12 3.2z"/>'
        + '<path d="M10.1 18.4a1.9 1.9 0 0 0 3.8 0"/></svg>';
    var ICON_INBOX = '<svg class="cpchat-ico cpchat-ico-sm" viewBox="0 0 24 24" width="13" height="13" fill="none"'
        + ' stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        + '<path d="M3.5 12.5 5.8 5h12.4l2.3 7.5v5.2a1.1 1.1 0 0 1-1.1 1.1H4.6a1.1 1.1 0 0 1-1.1-1.1z"/>'
        + '<path d="M3.5 12.5h5l1.4 2.4h4.2l1.4-2.4h5"/></svg>';

    function build() {
        var nav = document.querySelector('.navbar-custom-menu ul.nav.navbar-nav');
        if (!nav) {
            return false;
        }
        bell = document.createElement('li');
        bell.className = 'cpchat-bell dropdown';
        bell.innerHTML =
            '<a href="#" class="dropdown-toggle" data-toggle="dropdown" aria-expanded="false" title="Captive Portal Chat">'
            + ICON_BELL
            + '<span class="cpchat-dot"></span>'
            + '<span class="cpchat-count">0</span>'
            + '</a>'
            + '<ul class="dropdown-menu cpchat-menu">'
            + '<li class="cpchat-head"><span>New captive portal chats</span>'
            + '<small class="cpchat-open"></small></li>'
            + '<li class="cpchat-list"><ul class="cpchat-items"></ul></li>'
            + '<li class="cpchat-foot"><a href="' + cfg.inbox + '">' + ICON_INBOX + ' Open chat inbox</a></li>'
            + '</ul>';
        nav.insertBefore(bell, nav.firstChild);
        badge = bell.querySelector('.cpchat-count');
        menu = bell.querySelector('.cpchat-menu');

        bell.querySelector('a.dropdown-toggle').onclick = function (ev) {
            ev.preventDefault();
            ev.stopPropagation();
            askPermission();
            toggle();
        };
        document.addEventListener('click', function () {
            if (bell && bell.className.indexOf('open') !== -1) {
                bell.className = bell.className.replace(' open', '');
            }
        });
        return true;
    }

    function toggle() {
        if (!bell) {
            return;
        }
        bell.className = bell.className.indexOf('open') !== -1
            ? bell.className.replace(' open', '')
            : bell.className + ' open';
    }

    function render() {
        if (!menu) {
            return;
        }
        var list = menu.querySelector('.cpchat-items');
        var html = '';
        if (!items.length) {
            html = '<li class="cpchat-empty">No new messages</li>';
        } else {
            for (var i = 0; i < items.length; i++) {
                var m = items[i];
                var who = m.name || m.phone || m.mac || 'Customer';
                html += '<li><a href="' + withParam(cfg.inbox, 'id', m.conversation_id) + '">'
                    + '<span class="cpchat-who">' + escapeText(who) + '</span>'
                    + '<span class="cpchat-when">' + escapeText(m.ago || m.time || '') + '</span>'
                    + '<span class="cpchat-text">' + escapeText(m.body) + '</span>'
                    + '</a></li>';
            }
        }
        list.innerHTML = html;
        menu.querySelector('.cpchat-open').textContent = openChats ? (openChats + ' open') : '';
        badge.textContent = unreadTotal > 99 ? '99+' : String(unreadTotal);
        bell.className = bell.className.replace(/ has-unread/g, '') + (unreadTotal > 0 ? ' has-unread' : '');
        titleFlash();
    }

    /* ---------------- notifications ---------------- */

    function askPermission() {
        if (typeof window.Notification === 'undefined') {
            return;
        }
        try {
            if (Notification.permission === 'default') {
                Notification.requestPermission();
            }
        } catch (e) { }
    }

    function notify(m) {
        var who = m.name || m.phone || m.mac || 'Customer';
        var text = (m.body || '').slice(0, 140);
        if (typeof window.Notification !== 'undefined' && Notification.permission === 'granted' && isSecureContext()) {
            try {
                var n = new Notification('Captive portal chat: ' + who, {
                    body: text,
                    tag: 'cpchat-' + m.id,
                    icon: (document.querySelector('link[rel*="icon"]') || {}).href,
                    silent: !cfg.sound
                });
                n.onclick = function () {
                    window.location.href = withParam(cfg.inbox, 'id', m.conversation_id);
                    window.focus();
                };
                return;
            } catch (e) { /* some browsers reject constructor form */ }
        }
        toast(who, text, m.conversation_id);
    }

    function isSecureContext() {
        return window.isSecureContext === true || window.location.protocol === 'https:' || window.isSecureContext === undefined;
    }

    function toast(who, text, cid) {
        if (!document.body) {
            return;
        }
        var t = document.createElement('div');
        t.className = 'cpchat-toast';
        t.innerHTML = '<b>New chat: ' + escapeText(who) + '</b><span>' + escapeText(text) + '</span>';
        t.onclick = function () {
            window.location.href = withParam(cfg.inbox, 'id', cid);
        };
        document.body.appendChild(t);
        setTimeout(function () {
            t.className += ' out';
        }, 4200);
        setTimeout(function () {
            if (t.parentNode) {
                t.parentNode.removeChild(t);
            }
        }, 4800);
    }

    var audio = null;
    function beep() {
        if (!cfg.sound) {
            return;
        }
        try {
            var AC = window.AudioContext || window.webkitAudioContext;
            if (!AC) {
                return;
            }
            audio = audio || new AC();
            var o = audio.createOscillator();
            var g = audio.createGain();
            o.frequency.value = 980;
            o.connect(g);
            g.connect(audio.destination);
            g.gain.value = 0.05;
            o.start();
            setTimeout(function () {
                try {
                    o.stop();
                } catch (e) { }
            }, 120);
        } catch (e) { }
    }

    function titleFlash() {
        if (flashTimer) {
            clearInterval(flashTimer);
            flashTimer = null;
        }
        if (!unreadTotal) {
            document.title = originalTitle;
            return;
        }
        if (!document.hidden) {
            document.title = originalTitle;
            return;
        }
        var on = false;
        flashTimer = setInterval(function () {
            on = !on;
            document.title = on ? '(' + unreadTotal + ') New chat' : originalTitle;
        }, 1200);
    }

    /* ---------------- polling ---------------- */

    function poll() {
        get(withParam(urls.poll, 'since', last), function (res) {
            if (res && res.success) {
                var msgs = res.messages || [];
                unreadTotal = res.unread || 0;
                openChats = res.open_chats || 0;
                if (res.last_id > last) {
                    last = res.last_id;
                    lsSet(storeKey, String(last));
                }
                if (msgs.length) {
                    if (firstRun) {
                        // do not spam notifications for history on the very first load
                        items = msgs.slice(-8).reverse();
                    } else {
                        items = msgs.slice(-8).reverse().concat(items).slice(0, 8);
                        for (var i = 0; i < msgs.length; i++) {
                            notify(msgs[i]);
                        }
                        beep();
                    }
                }
                firstRun = false;
                render();
            }
            schedule(nextDelay());
        });
    }

    function nextDelay() {
        return document.hidden ? interval * 2 : interval;
    }

    function schedule(ms) {
        setTimeout(poll, ms);
    }

    function start() {
        var saved = parseInt(lsGet(storeKey), 10);
        last = saved > 0 ? saved : 0;
        if (last === 0) {
            // first time on this browser: do not announce old messages
            firstRun = true;
        }
        if (!build()) {
            setTimeout(start, 800);
            return;
        }
        render();
        poll();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }
})();
