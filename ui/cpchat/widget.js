/*!
 * Captive Portal Chat widget for PHPNuxBill
 * Runs inside MikroTik hotspot pages (login.html / logout.html / status.html).
 * No dependencies, no cookies, ES5 safe for old captive portal webviews.
 */
(function () {
    'use strict';

    var cfg = window.CPCHAT_CFG || {};
    var page = window.CPCHAT_PAGE || {};
    if (!cfg.enabled) {
        return;
    }
    var urls = cfg.urls || {};
    var pollOpen = parseInt(cfg.pollOpen, 10) || 5;
    var pollClosed = parseInt(cfg.pollClosed, 10) || 20;
    var maxLength = parseInt(cfg.maxLength, 10) || 1000;

    var store = {
        get: function (k) {
            try {
                return window.localStorage.getItem(k);
            } catch (e) {
                return store.mem[k] || null;
            }
        },
        set: function (k, v) {
            try {
                window.localStorage.setItem(k, v);
            } catch (e) {
                store.mem[k] = v;
            }
        },
        del: function (k) {
            try {
                window.localStorage.removeItem(k);
            } catch (e) {
                delete store.mem[k];
            }
        },
        mem: {}
    };

    var state = {
        token: store.get('cpchat_token') || '',
        seen: parseInt(store.get('cpchat_seen'), 10) || 0,
        profile: {},
        open: false,
        unread: 0,
        sending: false,
        offline: false,
        timer: null,
        status: 'open',
        rendered: {}
    };
    try {
        state.profile = JSON.parse(store.get('cpchat_profile') || '{}');
    } catch (e) {
        state.profile = {};
    }

    var queue = [];
    try {
        queue = JSON.parse(store.get('cpchat_queue') || '[]') || [];
    } catch (e) {
        queue = [];
    }

    function saveQueue() {
        store.set('cpchat_queue', JSON.stringify(queue.slice(-20)));
    }

    function uuid() {
        return 'xxxxxxxx-xxxx-4xxx'.replace(/[x]/g, function () {
            return Math.floor(Math.random() * 16).toString(16);
        }) + '-' + Date.now().toString(36);
    }

    function meta() {
        return {
            mac: page.mac || '',
            ip: page.ip || '',
            username: page.username || '',
            router: page.router || '',
            page: page.page || 'login'
        };
    }

    /* ---------------- transport (XHR: works on ancient webviews) -------- */

    function post(url, data, done) {
        var body = [];
        data = data || {};
        for (var k in data) {
            if (Object.prototype.hasOwnProperty.call(data, k) && data[k] !== null && typeof data[k] !== 'undefined') {
                body.push(encodeURIComponent(k) + '=' + encodeURIComponent(data[k]));
            }
        }
        var xhr = new XMLHttpRequest();
        xhr.open('POST', url, true);
        try {
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
        } catch (e) { /* some webviews reject this */ }
        xhr.timeout = 15000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) {
                return;
            }
            if (xhr.status === 0) {
                done({ error: 'offline' });
                return;
            }
            var json = null;
            try {
                json = JSON.parse(xhr.responseText);
            } catch (e) {
                done({ error: 'bad response' });
                return;
            }
            done(json || { error: 'empty' });
        };
        xhr.onontimeout = null;
        xhr.ontimeout = function () { done({ error: 'timeout' }); };
        xhr.onerror = function () { done({ error: 'offline' }); };
        try {
            xhr.send(body.join('&'));
        } catch (e) {
            done({ error: 'offline' });
        }
    }

    /* ---------------- ui ---------------- */

    var els = {};

    function el(tag, cls, text) {
        var n = document.createElement(tag);
        if (cls) {
            n.className = cls;
        }
        if (typeof text === 'string') {
            n.appendChild(document.createTextNode(text));
        }
        return n;
    }

    function injectStyle() {
        if (document.getElementById('cpchat-style')) {
            return;
        }
        var css = [
            '.cpchat-btn{position:fixed;right:16px;bottom:16px;z-index:99990;border:0;border-radius:50%;width:56px;height:56px;',
            'background:#1e88e5;color:#fff;box-shadow:0 6px 18px rgba(0,0,0,.35);font-size:24px;line-height:56px;cursor:pointer;padding:0;',
            'display:flex;align-items:center;justify-content:center;flex-direction:column;}',
            '.cpchat-btn svg{width:26px;height:26px;fill:#fff}',
            '.cpchat-badge{position:absolute;top:-2px;right:-2px;min-width:20px;height:20px;border-radius:10px;background:#e53935;color:#fff;',
            'font-size:12px;line-height:20px;padding:0 5px;display:none;font-family:sans-serif}',
            '.cpchat-badge.on{display:block}',
            '.cpchat-panel{position:fixed;right:16px;bottom:16px;z-index:99991;width:340px;max-width:calc(100vw - 24px);height:460px;',
            'max-height:calc(100vh - 32px);background:#fff;border-radius:12px;box-shadow:0 12px 40px rgba(0,0,0,.35);display:none;',
            'flex-direction:column;overflow:hidden;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;font-size:14px;color:#222}',
            '.cpchat-panel.on{display:flex}',
            '@media (max-width:480px){.cpchat-panel{right:8px;left:8px;bottom:8px;width:auto;height:72vh}}',
            '.cpchat-head{background:#1e88e5;color:#fff;padding:10px 12px;display:flex;align-items:center;gap:8px}',
            '.cpchat-head b{flex:1;font-size:14px;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
            '.cpchat-head button{background:rgba(255,255,255,.18);border:0;color:#fff;border-radius:6px;padding:4px 8px;font-size:12px;cursor:pointer}',
            '.cpchat-body{flex:1;overflow-y:auto;padding:12px;background:#f4f6f9;-webkit-overflow-scrolling:touch}',
            '.cpchat-row{display:flex;margin-bottom:8px}',
            '.cpchat-row.me{justify-content:flex-end}',
            '.cpchat-bubble{max-width:80%;padding:8px 10px;border-radius:10px;background:#fff;box-shadow:0 1px 2px rgba(0,0,0,.12);',
            'white-space:pre-wrap;word-break:break-word;line-height:1.35}',
            '.cpchat-row.me .cpchat-bubble{background:#1e88e5;color:#fff}',
            '.cpchat-meta{display:block;font-size:10px;opacity:.7;margin-top:3px}',
            '.cpchat-sys{align-self:center;font-size:11px;color:#66727f;text-align:center;background:#e8edf2;border-radius:8px;padding:5px 8px;margin:0 auto 10px;max-width:90%}',
            '.cpchat-foot{border-top:1px solid #e3e8ee;padding:8px;display:flex;gap:8px;align-items:flex-end;background:#fff}',
            '.cpchat-foot textarea{flex:1;resize:none;border:1px solid #cfd8e3;border-radius:8px;padding:8px;font-size:14px;max-height:88px;',
            'min-height:38px;font-family:inherit;outline:none}',
            '.cpchat-foot button{border:0;background:#1e88e5;color:#fff;border-radius:8px;padding:0 14px;height:38px;cursor:pointer;font-size:14px}',
            '.cpchat-foot button[disabled]{opacity:.55}',
            '.cpchat-note{padding:6px 10px;font-size:11px;color:#8a6d3b;background:#fcf8e3;border-top:1px solid #f5e6c8;display:none}',
            '.cpchat-note.on{display:block}',
            '.cpchat-form{padding:14px;background:#fff}',
            '.cpchat-form label{display:block;font-size:12px;color:#55606b;margin:0 0 4px}',
            '.cpchat-form input{width:100%;box-sizing:border-box;border:1px solid #cfd8e3;border-radius:8px;padding:9px;font-size:14px;margin-bottom:10px;outline:none}',
            '.cpchat-form button{width:100%;border:0;background:#1e88e5;color:#fff;border-radius:8px;padding:11px;font-size:15px;cursor:pointer}',
            '.cpchat-err{color:#c0392b;font-size:12px;margin:-4px 0 8px;display:none}',
            '.cpchat-err.on{display:block}',
            '.cpchat-pending{opacity:.6}',
            '.cpchat-hp{position:absolute!important;left:-9999px;top:-9999px;width:1px;height:1px;overflow:hidden;opacity:0}',
            '.cpchat-cap{font-size:12px;color:#55606b;margin:-4px 0 10px}',
            '.cpchat-cap b{display:inline-block;background:#eef2f7;border-radius:6px;padding:3px 8px;margin-left:4px;color:#1a202c;font-size:13px}',
            '.cpchat-state{font-size:10px;background:rgba(255,255,255,.22);border-radius:10px;padding:2px 8px;white-space:nowrap}',
            '.cpchat-state.off{background:#c62828}',
            '.cpchat-offline{font-size:12px;color:#8a6d3b;background:#fcf8e3;border:1px solid #f5e6c8;border-radius:8px;padding:8px 10px;margin:0 0 12px}',
            '.cpchat-offline b{display:block;font-size:11px;text-transform:uppercase;letter-spacing:.4px;margin-bottom:2px}',
            '.cpchat-brand{font-size:10px;color:#98a3ae;text-align:center;padding:4px 0 6px;background:#fff}'
        ].join('');
        var s = el('style');
        s.id = 'cpchat-style';
        s.appendChild(document.createTextNode(css));
        document.head.appendChild(s);
    }

    function bubble(m) {
        if (m.sender === 'system') {
            var sys = el('div', 'cpchat-row');
            sys.appendChild(el('div', 'cpchat-sys', m.body));
            return sys;
        }
        var row = el('div', 'cpchat-row' + (m.sender === 'customer' ? ' me' : ''));
        var b = el('div', 'cpchat-bubble');
        b.appendChild(document.createTextNode(m.body));
        var stamp = el('span', 'cpchat-meta', m.time || '');
        if (m.pending) {
            row.className += ' cpchat-pending';
            stamp.textContent = 'sending\u2026';
        }
        if (m.failed) {
            stamp.textContent = m.failed;
            b.style.cursor = 'pointer';
            b.onclick = function () {
                retry(m.ref);
            };
        }
        b.appendChild(stamp);
        if (m.ref) {
            b.setAttribute('data-ref', m.ref);
        }
        row.appendChild(b);
        return row;
    }

    function scrollBottom() {
        var b = els.body;
        b.scrollTop = b.scrollHeight;
    }

    function renderMessages(list, append) {
        if (!append) {
            els.body.innerHTML = '';
            state.rendered = {};
        }
        for (var i = 0; i < list.length; i++) {
            state.rendered[list[i].id] = true;
            els.body.appendChild(bubble(list[i]));
        }
        scrollBottom();
    }

    function setBadge(n) {
        state.unread = n;
        if (!els.badge) {
            return;
        }
        els.badge.textContent = n > 9 ? '9+' : String(n);
        els.badge.className = 'cpchat-badge' + (n > 0 ? ' on' : '');
    }

    function note(text) {
        if (!text) {
            els.note.className = 'cpchat-note';
            return;
        }
        els.note.textContent = text;
        els.note.className = 'cpchat-note on';
    }

    function showForm(message) {
        els.form.style.display = 'block';
        els.chat.style.display = 'none';
        els.name.value = state.profile.name || '';
        els.phone.value = state.profile.phone || '';
        els.err.textContent = message || '';
        els.err.className = 'cpchat-err' + (message ? ' on' : '');
        if (els.offline) {
            els.offline.style.display = cfg.open ? 'none' : 'block';
        }
        if (cfg.captcha) {
            loadCaptcha();
        }
        setTimeout(function () {
            (state.profile.name ? els.phone : els.name).focus();
        }, 60);
    }

    /* ---------------- anti abuse helpers ---------------- */

    function honeypotData(data) {
        if (!cfg.honeypot || !els.hp) {
            return data;
        }
        data.website = els.hp.value;
        data.url = els.hp2 ? els.hp2.value : '';
        return data;
    }

    function loadCaptcha() {
        if (!urls.captcha) {
            return;
        }
        state.captcha = null;
        els.capQ.textContent = 'Loading…';
        els.capAnswer.value = '';
        post(urls.captcha, {}, function (res) {
            if (res.error || !res.required || !res.question) {
                els.cap.style.display = 'none';
                return;
            }
            state.captcha = res.token;
            els.capQ.innerHTML = '';
            els.capQ.appendChild(document.createTextNode('Spam check: '));
            els.capQ.appendChild(el('b', '', res.question));
            els.cap.style.display = 'block';
            els.capAnswer.value = '';
        });
    }

    function showChat() {
        els.form.style.display = 'none';
        els.chat.style.display = 'flex';
    }

    function openPanel() {
        state.open = true;
        els.panel.className = 'cpchat-panel on';
        els.button.style.display = 'none';
        if (!state.token) {
            showForm('');
        } else {
            showChat();
            poll(true);
        }
        tick();
        try {
            els.input.focus();
        } catch (e) { }
    }

    function closePanel() {
        state.open = false;
        els.panel.className = 'cpchat-panel';
        els.button.style.display = 'flex';
        tick();
    }

    /* ---------------- actions ---------------- */

    function startChat() {
        var name = els.name.value.replace(/^\s+|\s+$/g, '');
        var phone = els.phone.value.replace(/^\s+|\s+$/g, '');
        if (name.length < 2) {
            showForm('Please enter your name');
            return;
        }
        var digits = phone.replace(/\D/g, '');
        if (digits.length < 6 || digits.length > 15) {
            showForm('Please enter a valid phone number');
            return;
        }
        state.profile = { name: name, phone: phone };
        store.set('cpchat_profile', JSON.stringify(state.profile));
        var data = meta();
        data.name = name;
        data.phone = phone;
        data.token = state.token;
        honeypotData(data);
        if (cfg.captcha) {
            if (!state.captcha || els.capAnswer.value === '') {
                showForm('Please answer the spam check');
                return;
            }
            data.captcha = els.capAnswer.value;
            data.captcha_token = state.captcha;
        }
        els.startBtn.disabled = true;
        post(urls.start, data, function (res) {
            els.startBtn.disabled = false;
            if (res.error || !res.success) {
                if (cfg.captcha) {
                    loadCaptcha();
                }
                showForm(res.error ? 'Cannot reach support. Try again.' : res.message);
                return;
            }
            if (res.config) {
                cfg.open = res.config.open !== false;
                if (res.config.awayMessage) {
                    cfg.awayMessage = res.config.awayMessage;
                }
                if (res.config.hours) {
                    cfg.hours = res.config.hours;
                }
                paintState();
            }
            state.token = res.token;
            state.status = res.status;
            state.seen = 0;
            store.set('cpchat_token', res.token);
            showChat();
            els.body.innerHTML = '';
            renderMessages(res.messages || [], false);
            if (res.messages && res.messages.length) {
                state.seen = res.messages[res.messages.length - 1].id;
                store.set('cpchat_seen', String(state.seen));
            }
            setBadge(0);
            note('');
            tick();
            flushQueue();
        });
    }

    function poll(full) {
        if (!state.token) {
            return;
        }
        var data = meta();
        data.token = state.token;
        data.since = full ? 0 : state.seen;
        post(urls.poll, data, function (res) {
            if (res.error) {
                state.offline = true;
                if (state.open) {
                    note('Connection lost, retrying…');
                }
                return;
            }
            state.offline = false;
            if (!res.success) {
                if (state.open) {
                    showForm(res.message || 'Please start a new chat');
                    state.token = '';
                    store.del('cpchat_token');
                    store.del('cpchat_seen');
                }
                return;
            }
            note('');
            state.status = res.status;
            var list = res.messages || [];
            if (full) {
                renderMessages(list, false);
            } else if (list.length) {
                var newReplies = 0;
                for (var i = 0; i < list.length; i++) {
                    if (list[i].id <= state.seen || state.rendered[list[i].id]) {
                        continue;
                    }
                    state.rendered[list[i].id] = true;
                    els.body.appendChild(bubble(list[i]));
                    if (list[i].sender !== 'customer') {
                        newReplies++;
                    }
                }
                scrollBottom();
                if (newReplies > 0) {
                    beep();
                    if (!state.open) {
                        setBadge(state.unread + newReplies);
                    }
                }
            }
            if (res.last_id && res.last_id > state.seen) {
                state.seen = res.last_id;
                store.set('cpchat_seen', String(state.seen));
            }
            if (full && state.seen === 0) {
                state.seen = res.last_id || 0;
                store.set('cpchat_seen', String(state.seen));
            }
            if (typeof res.open === 'boolean') {
                cfg.open = res.open;
                paintState();
            }
            if (res.status === 'closed') {
                setBadge(0);
                note('This chat has been closed. You can start a new one.');
                els.endBtn.style.display = 'inline-block';
            }
        });
    }

    function send(body, ref) {
        var data = meta();
        data.token = state.token;
        data.body = body;
        data.ref = ref;
        honeypotData(data);
        post(urls.send, data, function (res) {
            if (res.error || !res.success) {
                markPending(ref, res.error ? 'not sent, tap to retry' : (res.message || 'not sent'), true);
                return;
            }
            if (res.stripped) {
                note('Links were removed from your message.');
                setTimeout(function () { note(''); }, 6000);
            }
            dropQueue(ref);
            if (res.id && res.id > state.seen) {
                state.seen = res.id;
                store.set('cpchat_seen', String(state.seen));
            }
            markSent(ref, res.id);
        });
    }

    function markSent(ref, id) {
        var nodes = els.body.querySelectorAll('.cpchat-bubble');
        for (var i = 0; i < nodes.length; i++) {
            if (nodes[i].getAttribute('data-ref') === ref) {
                var row = nodes[i].parentNode;
                row.className = 'cpchat-row me';
                var stamp = nodes[i].querySelector('.cpchat-meta');
                if (stamp) {
                    stamp.textContent = timeStr();
                }
                nodes[i].style.cursor = '';
                nodes[i].onclick = null;
                state.rendered[id] = true;
                return;
            }
        }
        state.rendered[id] = true;
    }

    function sendMessage() {
        var text = els.input.value.replace(/^\s+|\s+$/g, '');
        if (!text || !state.token) {
            return;
        }
        var ref = uuid();
        els.input.value = '';
        autosize();
        els.body.appendChild(bubble({ body: text, sender: 'customer', time: timeStr(), ref: ref, pending: true }));
        scrollBottom();
        queue.push({ ref: ref, body: text });
        saveQueue();
        send(text, ref);
    }

    function flushQueue() {
        if (!state.token || !queue.length) {
            return;
        }
        var items = queue.slice();
        for (var i = 0; i < items.length; i++) {
            send(items[i].body, items[i].ref);
        }
    }

    function dropQueue(ref) {
        var out = [];
        for (var i = 0; i < queue.length; i++) {
            if (queue[i].ref !== ref) {
                out.push(queue[i]);
            }
        }
        queue = out;
        saveQueue();
    }

    function markPending(ref, text, failed) {
        var nodes = els.body.querySelectorAll('.cpchat-bubble');
        for (var i = 0; i < nodes.length; i++) {
            if (nodes[i].getAttribute('data-ref') === ref) {
                var stamp = nodes[i].querySelector('.cpchat-meta');
                if (stamp) {
                    stamp.textContent = text;
                }
                if (failed) {
                    nodes[i].style.cursor = 'pointer';
                    (function (target, r) {
                        target.onclick = function () {
                            retry(r);
                        };
                    })(nodes[i], ref);
                }
                nodes[i].parentNode.className += ' cpchat-pending';
            }
        }
    }

    function endChat() {
        if (!state.token) {
            return;
        }
        var data = meta();
        data.token = state.token;
        post(urls.close, data, function () {
            state.token = '';
            state.seen = 0;
            queue = [];
            saveQueue();
            store.del('cpchat_token');
            store.del('cpchat_seen');
            els.endBtn.style.display = 'none';
            showForm('');
        });
    }

    function retry(ref) {
        var item = null;
        for (var i = 0; i < queue.length; i++) {
            if (queue[i].ref === ref) {
                item = queue[i];
            }
        }
        if (!item) {
            return;
        }
        markPending(ref, 'sending\u2026', false);
        send(item.body, item.ref);
    }

    function timeStr() {
        var d = new Date();
        return ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2);
    }

    var audioCtx = null;
    function beep() {
        if (!cfg.sound) {
            return;
        }
        try {
            var AC = window.AudioContext || window.webkitAudioContext;
            if (!AC) {
                return;
            }
            audioCtx = audioCtx || new AC();
            var o = audioCtx.createOscillator();
            var g = audioCtx.createGain();
            o.frequency.value = 880;
            o.connect(g);
            g.connect(audioCtx.destination);
            g.gain.value = 0.06;
            o.start();
            setTimeout(function () {
                try {
                    o.stop();
                    g.disconnect();
                } catch (e) { }
            }, 140);
        } catch (e) { }
    }

    function autosize() {
        els.input.style.height = '38px';
        els.input.style.height = Math.min(88, els.input.scrollHeight) + 'px';
    }

    var lastTick = 0;
    function tick() {
        var now = Date.now();
        if (now - lastTick < 4000) {
            return;
        }
        lastTick = now;
        var idle = state.open ? pollOpen : pollClosed;
        var wait = idle * 1000;
        if (document.hidden) {
            wait = idle * 2000;
        }
        clearTimeout(state.timer);
        state.timer = setTimeout(function () {
            if (state.token) {
                poll(false);
            }
            flushQueue();
            tick();
        }, wait);
    }

    /* ---------------- boot ---------------- */

    function build() {
        injectStyle();
        var icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        icon.setAttribute('viewBox', '0 0 24 24');
        var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', 'M20 2H4a2 2 0 0 0-2 2v18l4-4h14a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2zM7 9h10v1.5H7V9zm6 4.5H7v-1.5h6v1.5zM7 6h10v1.5H7V6z');
        icon.appendChild(path);

        els.badge = el('span', 'cpchat-badge', '');
        els.button = el('button', 'cpchat-btn');
        els.button.setAttribute('type', 'button');
        els.button.setAttribute('aria-label', cfg.title || 'Chat');
        els.button.appendChild(icon);
        els.button.appendChild(els.badge);
        els.button.onclick = openPanel;

        els.panel = el('div', 'cpchat-panel');
        var head = el('div', 'cpchat-head');
        head.appendChild(el('b', '', cfg.title || 'Chat with us'));
        els.state = el('span', 'cpchat-state', '');
        head.appendChild(els.state);
        els.endBtn = el('button', '', 'New chat');
        els.endBtn.setAttribute('type', 'button');
        els.endBtn.style.display = 'none';
        els.endBtn.onclick = endChat;
        var closeBtn = el('button', '', 'Close');
        closeBtn.setAttribute('type', 'button');
        closeBtn.onclick = closePanel;
        head.appendChild(els.endBtn);
        head.appendChild(closeBtn);

        els.body = el('div', 'cpchat-body');
        els.note = el('div', 'cpchat-note', '');

        els.input = document.createElement('textarea');
        els.input.placeholder = 'Type your message…';
        els.input.setAttribute('rows', '1');
        els.input.maxLength = maxLength;
        els.input.oninput = autosize;
        els.input.onkeydown = function (ev) {
            if (ev && ev.key === 'Enter' && !ev.shiftKey) {
                ev.preventDefault();
                sendMessage();
            }
        };
        var sendBtn = el('button', '', 'Send');
        sendBtn.setAttribute('type', 'button');
        sendBtn.onclick = sendMessage;
        var foot = el('div', 'cpchat-foot');
        foot.appendChild(els.input);
        foot.appendChild(sendBtn);

        els.chat = el('div', '');
        els.chat.style.display = 'none';
        els.chat.style.flex = '1';
        els.chat.style.flexDirection = 'column';
        els.chat.style.minHeight = '0';
        els.chat.appendChild(els.body);
        els.chat.appendChild(els.note);
        els.chat.appendChild(foot);

        els.form = el('div', 'cpchat-form');
        els.form.style.display = 'none';
        els.form.appendChild(el('div', 'cpchat-sys', cfg.welcome || ''));
        els.offline = el('div', 'cpchat-offline', '');
        els.offline.appendChild(el('b', '', (cfg.hours && cfg.hours.length) ? cfg.hours : 'Offline'));
        els.offline.appendChild(document.createTextNode(cfg.awayMessage || 'We are offline right now, leave your question and we will reply as soon as we are back.'));
        els.offline.style.display = 'none';
        els.form.appendChild(els.offline);
        els.form.appendChild(el('label', '', 'Your name'));
        els.name = el('input');
        els.name.setAttribute('type', 'text');
        els.name.setAttribute('autocomplete', 'name');
        els.name.maxLength = 60;
        els.form.appendChild(els.name);
        els.form.appendChild(el('label', '', 'Phone number'));
        els.phone = el('input');
        els.phone.setAttribute('type', 'tel');
        els.phone.setAttribute('autocomplete', 'tel');
        els.phone.maxLength = 24;
        els.form.appendChild(els.phone);
        if (cfg.honeypot) {
            // hidden trap fields: a real visitor never sees or fills them
            var hp = el('div', 'cpchat-hp');
            els.hp = el('input');
            els.hp.setAttribute('type', 'text');
            els.hp.setAttribute('tabindex', '-1');
            els.hp.setAttribute('autocomplete', 'off');
            els.hp2 = el('input');
            els.hp2.setAttribute('type', 'text');
            els.hp2.setAttribute('tabindex', '-1');
            els.hp2.setAttribute('autocomplete', 'off');
            hp.appendChild(els.hp);
            hp.appendChild(els.hp2);
            els.form.appendChild(hp);
        }
        if (cfg.captcha) {
            els.cap = el('div', 'cpchat-cap');
            els.capQ = el('span', '', 'Spam check: loading…');
            els.cap.appendChild(els.capQ);
            els.capAnswer = el('input');
            els.capAnswer.setAttribute('type', 'text');
            els.capAnswer.setAttribute('inputmode', 'numeric');
            els.capAnswer.setAttribute('autocomplete', 'off');
            els.capAnswer.maxLength = 4;
            els.cap.appendChild(els.capAnswer);
            els.cap.style.display = 'none';
            els.form.appendChild(els.cap);
        }
        els.err = el('div', 'cpchat-err', '');
        els.form.appendChild(els.err);
        els.startBtn = el('button', '', 'Start chat');
        els.startBtn.setAttribute('type', 'button');
        els.startBtn.onclick = startChat;
        els.form.appendChild(els.startBtn);

        els.panel.appendChild(head);
        els.panel.appendChild(els.chat);
        els.panel.appendChild(els.form);
        els.panel.appendChild(el('div', 'cpchat-brand', 'Powered by ' + (cfg.agent || 'PHPNuxBill')));

        function mount() {
            document.body.appendChild(els.button);
            document.body.appendChild(els.panel);
            if (state.token) {
                showChat();
                poll(true);
                flushQueue();
            } else {
                setBadge(0);
            }
            tick();
        }
        if (document.body) {
            paintState();
            mount();
        } else {
            document.addEventListener('DOMContentLoaded', function () {
                paintState();
                mount();
            });
        }
    }

    function paintState() {
        if (!els.state) {
            return;
        }
        if (cfg.open) {
            els.state.className = 'cpchat-state';
            els.state.textContent = 'Online';
        } else {
            els.state.className = 'cpchat-state off';
            els.state.textContent = (cfg.hours && cfg.hours.length) ? cfg.hours : 'Offline';
        }
    }

    build();

    window.CPCHAT = {
        open: openPanel,
        close: closePanel,
        state: state
    };
})();
