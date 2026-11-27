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
            '.cpchat-btn{position:fixed;right:18px;bottom:18px;z-index:99990;border:0;border-radius:50%;width:56px;height:56px;',
            'background:linear-gradient(135deg,#2563eb,#1d4ed8);color:#fff;box-shadow:0 8px 24px rgba(37,99,235,.4);font-size:24px;line-height:56px;cursor:pointer;padding:0;',
            'display:flex;align-items:center;justify-content:center;flex-direction:column;transition:transform .15s ease;}',
            '.cpchat-btn:hover{transform:scale(1.05)}',
            '.cpchat-btn svg{width:22px;height:22px;fill:#fff}',
            '.cpchat-badge{position:absolute;top:-3px;right:-3px;min-width:20px;height:20px;border-radius:10px;background:#ef4444;color:#fff;',
            'font-size:11px;font-weight:700;line-height:20px;padding:0 5px;display:none;font-family:sans-serif;box-shadow:0 2px 6px rgba(0,0,0,.25)}',
            '.cpchat-badge.on{display:block}',
            '.cpchat-panel{position:fixed;top:12px;right:12px;bottom:12px;z-index:99991;width:390px;max-width:calc(100vw - 24px);height:auto;max-height:none;',
            'background:#fff;border-radius:20px;box-shadow:0 20px 60px rgba(15,23,42,.18);border:1px solid #eef2f7;display:none;',
            'flex-direction:column;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Arial,sans-serif;font-size:14px;color:#111827}',
            '.cpchat-panel.on{display:flex}',
            '@media (max-width:480px){.cpchat-panel{top:auto;right:10px;left:10px;bottom:10px;width:auto;max-width:none;height:calc(100vh - 20px);max-height:600px;border-radius:18px}}',
            '.cpchat-head{background:#fff;color:#111827;padding:12px 14px 8px;display:flex;align-items:center;gap:10px;border-bottom:1px solid #f1f5f9}',
            '.cpchat-orb{width:34px;height:34px;border-radius:50%;flex-shrink:0;position:relative;overflow:visible;',
            'background:radial-gradient(circle at 30% 30%,#fde047 0%,#fb7185 38%,#c084fc 72%,#60a5fa 100%);',
            'box-shadow:0 4px 14px rgba(244,114,182,.35)}',
            '.cpchat-orb-img{width:34px;height:34px;border-radius:50%;object-fit:cover;display:block;background:#fff;border:1px solid #e5e7eb}',
            '.cpchat-orb-dot{position:absolute;right:0;bottom:0;width:9px;height:9px;border-radius:50%;background:#22c55e;border:2px solid #fff}',
            '.cpchat-orb-dot.off{background:#ef4444}',
            '.cpchat-head-info{flex:1;min-width:0}',
            '.cpchat-head-info b{display:block;font-size:13.5px;font-weight:600;color:#111827;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
            '.cpchat-state{display:inline-block;font-size:11px;font-weight:500;color:#6b7280;white-space:nowrap}',
            '.cpchat-state.off{color:#dc2626}',
            '.cpchat-icon-btn{background:transparent;border:0;color:#6b7280;width:30px;height:30px;border-radius:8px;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;padding:0}',
            '.cpchat-icon-btn:hover{background:#f3f4f6;color:#111827}',
            '.cpchat-head button.cpchat-new-btn{background:#f3f4f6;border:0;color:#374151;border-radius:8px;padding:4px 9px;font-size:11.5px;font-weight:600;cursor:pointer}',
            '.cpchat-body{flex:1;overflow-y:auto;padding:14px;background:#fff;-webkit-overflow-scrolling:touch;scrollbar-width:thin}',
            '.cpchat-row{display:flex;margin-bottom:10px}',
            '.cpchat-row.me{justify-content:flex-end}',
            '.cpchat-bubble{max-width:84%;padding:11px 14px;border-radius:16px;background:#fff;border:1px solid #e5e7eb;color:#111827;',
            'white-space:pre-wrap;word-break:break-word;line-height:1.45;font-size:13.5px}',
            '.cpchat-row.me .cpchat-bubble{background:#f3f4f6;border-color:#f3f4f6;color:#111827}',
            '.cpchat-meta{display:flex;align-items:center;justify-content:flex-end;gap:4px;font-size:10px;color:#9ca3af;margin-top:4px}',
            '.cpchat-tick{font-size:11px;font-weight:700;letter-spacing:-1px;color:#9ca3af}',
            '.cpchat-tick.seen{color:#2563eb}',
            '.cpchat-tick.fail{color:#dc2626}',
            '.cpchat-sys{align-self:center;font-size:11.5px;color:#6b7280;text-align:center;background:#f8fafc;border:1px solid #e5e7eb;border-radius:999px;padding:4px 12px;margin:0 auto 10px;max-width:90%}',
            '.cpchat-att-pill{display:flex;align-items:center;gap:10px;background:#111827;color:#fff;border-radius:12px;padding:9px 12px;margin-top:6px;text-decoration:none;font-size:12.5px;font-weight:500}',
            '.cpchat-att-pill:hover{background:#1f2937}',
            '.cpchat-att-ico{width:26px;height:26px;border-radius:7px;background:#16a34a;color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;flex-shrink:0}',
            '.cpchat-att-name{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
            '.cpchat-att-img{max-width:100%;max-height:180px;border-radius:12px;margin-top:6px;display:block;border:1px solid #e5e7eb}',
            '.cpchat-att-audio{width:220px;max-width:100%;height:34px;margin-top:6px;display:block}',
            '.cpchat-foot-wrap{padding:8px 12px 6px;background:#fff}',
            '.cpchat-foot{border:1px solid #e5e7eb;border-radius:16px;padding:5px 7px;display:flex;gap:4px;align-items:flex-end;background:#fff;box-shadow:0 2px 10px rgba(15,23,42,.05)}',
            '.cpchat-foot:focus-within{border-color:#cbd5e1;box-shadow:0 4px 14px rgba(15,23,42,.08)}',
            '.cpchat-foot textarea{flex:1;resize:none;border:0;padding:7px 6px;font-size:13.5px;max-height:84px;min-height:34px;font-family:inherit;outline:none;background:transparent;color:#111827}',
            '.cpchat-foot .cpchat-send-btn{border:0;background:#111827;color:#fff;border-radius:11px;width:32px;height:32px;display:none;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0}',
            '.cpchat-foot .cpchat-send-btn.on{display:inline-flex}',
            '.cpchat-rec-bar{display:none;align-items:center;justify-content:space-between;gap:8px;padding:7px 12px;border:1px solid #fecaca;background:#fef2f2;border-radius:14px;font-size:12.5px;color:#b91c1c}',
            '.cpchat-rec-bar.on{display:flex}',
            '.cpchat-rec-bar button{border:0;border-radius:8px;padding:4px 10px;font-size:12px;font-weight:600;cursor:pointer}',
            '.cpchat-note{padding:6px 12px;font-size:11px;color:#92400e;background:#fef3c7;border-top:1px solid #fde68a;display:none}',
            '.cpchat-note.on{display:block}',
            '.cpchat-form{flex:1;padding:14px 16px;background:#fff;overflow-y:auto;scrollbar-width:thin}',
            '.cpchat-form::-webkit-scrollbar,.cpchat-body::-webkit-scrollbar{width:5px}',
            '.cpchat-form::-webkit-scrollbar-thumb,.cpchat-body::-webkit-scrollbar-thumb{background:#cbd5e1;border-radius:99px}',
            '.cpchat-form label{display:block;font-size:12px;font-weight:600;color:#475569;margin:0 0 4px}',
            '.cpchat-form input{width:100%;box-sizing:border-box;border:1px solid #e5e7eb;border-radius:12px;padding:9px 11px;font-size:13.5px;margin-bottom:10px;outline:none;background:#f9fafb}',
            '.cpchat-form input:focus{border-color:#94a3b8;background:#fff}',
            '.cpchat-start-btn{width:100%;border:0;background:#111827;color:#fff;border-radius:12px;padding:10px;font-size:14px;font-weight:600;cursor:pointer;margin-top:2px}',
            '.cpchat-start-btn[disabled]{opacity:.6}',
            '.cpchat-err{color:#dc2626;font-size:12px;margin:-2px 0 8px;display:none}',
            '.cpchat-err.on{display:block}',
            '.cpchat-pending{opacity:.6}',
            '.cpchat-hp{position:absolute!important;left:-9999px;top:-9999px;width:1px;height:1px;overflow:hidden;opacity:0}',
            '.cpchat-cap{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:12px;color:#475569;margin:0 0 10px;background:#f9fafb;border:1px solid #e5e7eb;border-radius:12px;padding:7px 10px}',
            '.cpchat-cap b{display:inline-block;background:#fff;border:1px solid #e5e7eb;border-radius:6px;padding:2px 8px;margin-left:4px;color:#111827;font-size:12.5px}',
            '.cpchat-cap input{width:76px;margin:0;text-align:center;padding:6px 8px;background:#fff}',
            '.cpchat-offline{font-size:12px;color:#92400e;background:#fef3c7;border:1px solid #fde68a;border-radius:12px;padding:8px 10px;margin:0 0 10px}',
            '.cpchat-offline b{display:block;font-size:11px;text-transform:uppercase;letter-spacing:.4px;margin-bottom:2px}',
            '.cpchat-brand{font-size:7.5px;color:#9ca3af;opacity:.7;text-align:center;padding:4px 0 7px;background:#fff}',
            '.cpchat-quick{display:flex;flex-wrap:wrap;gap:6px;padding:8px 14px;background:#fff;border-bottom:1px solid #f1f5f9}',
            '.cpchat-form .cpchat-quick{background:transparent;border:0;padding:0;margin:0 0 12px}',
            '.cpchat-chip{width:auto;background:#f9fafb;border:1px solid #e5e7eb;color:#111827;border-radius:999px;padding:5px 12px;font-size:12px;font-weight:500;cursor:pointer;line-height:1.35;transition:all .15s}',
            '.cpchat-chip:hover{border-color:#111827;background:#fff}',
            '.cpchat-card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:10px 12px;margin:6px 0;font-size:12.5px;color:#111827;box-shadow:0 1px 4px rgba(15,23,42,.05)}',
            '.cpchat-card h4{margin:0 0 6px;font-size:13px;font-weight:700;color:#111827;display:flex;justify-content:space-between;align-items:center}',
            '.cpchat-plan{display:flex;justify-content:space-between;align-items:center;padding:6px 0;border-top:1px solid #f1f5f9}',
            '.cpchat-plan:first-of-type{border-top:0}',
            '.cpchat-plan b{color:#111827;font-size:13px}',
            '.cpchat-acct-in{width:100%;box-sizing:border-box;border:1px solid #e5e7eb;border-radius:10px;padding:7px 9px;font-size:12.5px;margin-bottom:6px;font-family:inherit}',
            '.cpchat-acct-btn{width:100%;border:0;border-radius:10px;padding:8px;background:#111827;color:#fff;font-size:12.5px;font-weight:600;cursor:pointer}',
            '.cpchat-typing{padding:4px 14px 8px;display:none}',
            '.cpchat-typing-dots{display:inline-flex;gap:4px;background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:8px 12px}',
            '.cpchat-typing-dots span{width:5px;height:5px;border-radius:50%;background:#9ca3af;animation:cpdot 1.2s infinite ease-in-out}',
            '.cpchat-typing-dots span:nth-child(2){animation-delay:.2s}',
            '.cpchat-typing-dots span:nth-child(3){animation-delay:.4s}',
            '@keyframes cpdot{0%,80%,100%{opacity:.3;transform:scale(.8)}40%{opacity:1;transform:scale(1)}}',
            '.cpchat-rate{display:none;align-items:center;justify-content:space-between;gap:8px;padding:8px 12px;background:#f0fdf4;border-top:1px solid #bbf7d0;font-size:12.5px;color:#166534}',
            '.cpchat-rate button{border:1px solid #cbd5e1;background:#fff;border-radius:8px;padding:4px 10px;font-size:12px;cursor:pointer}'
        ].join('');
        var s = el('style');
        s.id = 'cpchat-style';
        s.appendChild(document.createTextNode(css));
        document.head.appendChild(s);
    }

    function attUrl(url) {
        if (!url) { return ''; }
        return url + (url.indexOf('?') === -1 ? '?' : '&') + 'token=' + encodeURIComponent(state.token || '');
    }

    function renderAttachment(att) {
        if (!att || !att.url) { return null; }
        var url = attUrl(att.url);
        if (att.kind === 'image') {
            var a = el('a', '', '');
            a.href = url;
            a.target = '_blank';
            var img = el('img', 'cpchat-att-img', '');
            img.src = url;
            img.alt = att.name || 'image';
            a.appendChild(img);
            return a;
        }
        if (att.kind === 'audio') {
            var aud = el('audio', 'cpchat-att-audio', '');
            aud.controls = true;
            aud.preload = 'metadata';
            aud.src = url;
            return aud;
        }
        var pill = el('a', 'cpchat-att-pill', '');
        pill.href = url;
        pill.target = '_blank';
        var ext = (att.name || 'DOC').split('.').pop().toUpperCase().slice(0, 4);
        pill.appendChild(el('span', 'cpchat-att-ico', ext));
        pill.appendChild(el('span', 'cpchat-att-name', att.name || 'Document'));
        var dl = el('span', '', '\u2b07');
        dl.style.opacity = '.8';
        pill.appendChild(dl);
        return pill;
    }

    function bubble(m) {
        if (m.sender === 'system') {
            var sys = el('div', 'cpchat-row');
            sys.appendChild(el('div', 'cpchat-sys', m.body));
            return sys;
        }
        var row = el('div', 'cpchat-row' + (m.sender === 'customer' ? ' me' : ''));
        var b = el('div', 'cpchat-bubble');
        if (m.body && (!m.attachment || m.body !== m.attachment.name)) {
            b.appendChild(document.createTextNode(m.body));
        }
        if (m.attachment) {
            var attEl = renderAttachment(m.attachment);
            if (attEl) { b.appendChild(attEl); }
        }
        var stamp = el('span', 'cpchat-meta', '');
        stamp.appendChild(el('span', '', m.pending ? 'sending\u2026' : (m.failed ? m.failed : (m.time || ''))));
        if (m.sender === 'customer') {
            var tickCls = 'cpchat-tick' + (m.failed ? ' fail' : (m.is_read ? ' seen' : ''));
            var tickTxt = m.pending ? '\u23f3' : (m.failed ? '!' : (m.is_read ? '\u2713\u2713' : '\u2713'));
            stamp.appendChild(el('span', tickCls, tickTxt));
        }
        if (m.pending) {
            row.className += ' cpchat-pending';
        }
        if (m.failed) {
            b.style.cursor = 'pointer';
            b.onclick = function () {
                retry(m.ref);
            };
        }
        b.appendChild(stamp);
        if (m.id) {
            b.setAttribute('data-msg-id', String(m.id));
        }
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

    function addBotCard(title, builder) {
        var box = el('div', 'cpchat-card');
        var h = el('h4', '', '');
        h.appendChild(el('span', '', title));
        var x = el('span', '', '\u00d7');
        x.style.cursor = 'pointer';
        x.style.color = '#94a3b8';
        x.onclick = function () {
            if (box.parentNode) { box.parentNode.removeChild(box); }
        };
        h.appendChild(x);
        box.appendChild(h);
        builder(box);
        var target = (els.chat.style.display !== 'none') ? els.body : els.helperArea;
        target.innerHTML = (target === els.helperArea) ? '' : target.innerHTML;
        target.appendChild(box);
        if (target === els.body) { scrollBottom(); }
    }

    function openPlans() {
        if (!urls.plans) { return; }
        addBotCard('Hotspot Plans & Prices', function (box) {
            var loading = el('div', '', 'Loading plans\u2026');
            loading.style.color = '#64748b';
            box.appendChild(loading);
            post(urls.plans, {}, function (res) {
                box.removeChild(loading);
                if (!res || !res.success || !res.plans || !res.plans.length) {
                    box.appendChild(el('div', '', 'No active hotspot plans found.'));
                    return;
                }
                for (var i = 0; i < res.plans.length; i++) {
                    var p = res.plans[i];
                    var row = el('div', 'cpchat-plan');
                    var left = el('div', '', '');
                    left.appendChild(el('div', '', p.name));
                    var sub = el('div', '', p.validity || '');
                    sub.style.fontSize = '11px';
                    sub.style.color = '#64748b';
                    left.appendChild(sub);
                    row.appendChild(left);
                    row.appendChild(el('b', '', p.price));
                    box.appendChild(row);
                }
            });
        });
    }

    function openAccountCheck() {
        if (!urls.account) { return; }
        addBotCard('Check My Account', function (box) {
            var u = el('input', 'cpchat-acct-in');
            u.type = 'text';
            u.placeholder = 'Hotspot username';
            u.value = (page.username && !/^\$\(/.test(page.username)) ? page.username : '';
            var p = el('input', 'cpchat-acct-in');
            p.type = 'password';
            p.placeholder = 'Password';
            var msg = el('div', '', '');
            msg.style.fontSize = '12px';
            msg.style.marginBottom = '6px';
            var btn = el('button', 'cpchat-acct-btn', 'Check Status');
            btn.type = 'button';
            btn.onclick = function () {
                msg.style.color = '#dc2626';
                msg.textContent = '';
                btn.disabled = true;
                post(urls.account, { username: u.value, password: p.value }, function (res) {
                    btn.disabled = false;
                    if (!res || !res.success || !res.account) {
                        msg.textContent = (res && res.message) ? res.message : 'Unable to verify account';
                        return;
                    }
                    var a = res.account;
                    box.innerHTML = '<h4><span>' + a.username + '</span></h4>'
                        + '<div class="cpchat-plan"><span>Plan</span><b>' + a.plan + '</b></div>'
                        + '<div class="cpchat-plan"><span>Status</span><b>' + a.status + '</b></div>'
                        + '<div class="cpchat-plan"><span>Expires</span><span>' + a.expiration + '</span></div>'
                        + '<div class="cpchat-plan"><span>Balance</span><span>' + a.balance + '</span></div>';
                });
            };
            box.appendChild(u);
            box.appendChild(p);
            box.appendChild(msg);
            box.appendChild(btn);
        });
    }

    function showFaqAnswer(f) {
        addBotCard(f.q, function (box) {
            var ans = el('div', '', f.a);
            ans.style.lineHeight = '1.45';
            ans.style.marginBottom = '8px';
            box.appendChild(ans);
            if (els.chat.style.display === 'none') {
                var tip = el('div', '', 'Need more help? Fill in your name & phone below to chat with support.');
                tip.style.fontSize = '11.5px';
                tip.style.color = '#64748b';
                box.appendChild(tip);
            }
        });
    }

    function openFaqs() {
        var list = cfg.faqs || [];
        if (!list.length) { return; }
        addBotCard('Common Questions', function (box) {
            var wrap = el('div', '');
            wrap.style.display = 'flex';
            wrap.style.flexWrap = 'wrap';
            wrap.style.gap = '6px';
            for (var i = 0; i < list.length; i++) {
                (function (f) {
                    var c = el('button', 'cpchat-chip', f.q);
                    c.type = 'button';
                    c.onclick = function () { showFaqAnswer(f); };
                    wrap.appendChild(c);
                })(list[i]);
            }
            box.appendChild(wrap);
        });
    }

    function buildQuickBar(parent) {
        var canAccount = cfg.accountCheckEnabled && page.page === 'status';
        if (!cfg.plansEnabled && !canAccount && !(cfg.faqEnabled && (cfg.faqs || []).length)) {
            return null;
        }
        var bar = el('div', 'cpchat-quick');
        if (cfg.plansEnabled) {
            var b1 = el('button', 'cpchat-chip', 'Plans & Prices');
            b1.type = 'button';
            b1.onclick = openPlans;
            bar.appendChild(b1);
        }
        if (canAccount) {
            var b2 = el('button', 'cpchat-chip', 'My Account');
            b2.type = 'button';
            b2.onclick = openAccountCheck;
            bar.appendChild(b2);
        }
        if (cfg.faqEnabled && (cfg.faqs || []).length) {
            var b3 = el('button', 'cpchat-chip', 'FAQs');
            b3.type = 'button';
            b3.onclick = openFaqs;
            bar.appendChild(b3);
        }
        parent.appendChild(bar);
        return bar;
    }

    function matchFaq(text) {
        var list = cfg.faqs || [];
        if (!cfg.faqEnabled || !list.length) { return; }
        var low = text.toLowerCase();
        for (var i = 0; i < list.length; i++) {
            var kws = (list[i].kw || '').split(',');
            for (var k = 0; k < kws.length; k++) {
                var w = kws[k].replace(/^\s+|\s+$/g, '').toLowerCase();
                if (w.length >= 3 && low.indexOf(w) !== -1) {
                    showFaqAnswer(list[i]);
                    return;
                }
            }
        }
    }

    var lastTypingPing = 0;
    function pingTyping() {
        if (!state.token || !urls.typing || state.status !== 'open') { return; }
        var now = Date.now();
        if (now - lastTypingPing < 3000) { return; }
        lastTypingPing = now;
        post(urls.typing, { token: state.token }, function () {});
    }

    function sendRating(val) {
        if (!state.token || !urls.rate) { return; }
        post(urls.rate, { token: state.token, rating: val }, function (res) {
            if (res && res.success && els.rateBar) {
                els.rateBar.innerHTML = '<span>Thanks for your feedback!</span>';
            }
        });
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
            if (els.typing) {
                els.typing.style.display = res.typing ? 'block' : 'none';
            }
            if (res.admin_seen_id) {
                var myBubbles = els.body.querySelectorAll('.cpchat-row.me .cpchat-bubble[data-msg-id]');
                for (var sIdx = 0; sIdx < myBubbles.length; sIdx++) {
                    var mid = parseInt(myBubbles[sIdx].getAttribute('data-msg-id'), 10) || 0;
                    if (mid > 0 && mid <= res.admin_seen_id) {
                        var tk = myBubbles[sIdx].querySelector('.cpchat-tick');
                        if (tk) {
                            tk.className = 'cpchat-tick seen';
                            tk.textContent = '\u2713\u2713';
                        }
                    }
                }
            }
            if (res.status === 'closed') {
                setBadge(0);
                if (els.typing) { els.typing.style.display = 'none'; }
                note('This chat has been closed. You can start a new one.');
                els.endBtn.style.display = 'inline-block';
                if (els.rateBar && !res.rating) {
                    els.rateBar.style.display = 'flex';
                }
            } else if (els.rateBar) {
                els.rateBar.style.display = 'none';
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
                    stamp.innerHTML = '';
                    stamp.appendChild(el('span', '', timeStr()));
                    stamp.appendChild(el('span', 'cpchat-tick', '\u2713'));
                }
                if (id) {
                    nodes[i].setAttribute('data-msg-id', String(id));
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
        matchFaq(text);
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
        return ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2) + ':' + ('0' + d.getSeconds()).slice(-2);
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
            document.addEventListener('visibilitychange', function () {
                if (!document.hidden && state.token) {
                    poll(false);
                    tick();
                }
            });
        }, wait);
    }

    /* ---------------- boot ---------------- */

    function build() {
        injectStyle();
        var icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        icon.setAttribute('viewBox', '0 0 16 16');
        icon.setAttribute('width', '16');
        icon.setAttribute('height', '16');
        icon.setAttribute('fill', 'currentColor');
        var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', 'M14 1a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H4.414A2 2 0 0 0 3 11.586l-2 2V2a1 1 0 0 1 1-1zM2 0a2 2 0 0 0-2 2v12.793a.5.5 0 0 0 .854.353l2.853-2.853A1 1 0 0 1 4.414 12H14a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2z');
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
        var orb = el('div', 'cpchat-orb');
        if (cfg.logo) {
            var logoImg = el('img', 'cpchat-orb-img', '');
            logoImg.src = cfg.logo;
            logoImg.alt = cfg.agent || 'Logo';
            logoImg.onerror = function () { if (logoImg.parentNode) { logoImg.parentNode.removeChild(logoImg); } };
            orb.style.background = 'none';
            orb.style.boxShadow = 'none';
            orb.appendChild(logoImg);
        }
        els.orbDot = el('span', 'cpchat-orb-dot');
        orb.appendChild(els.orbDot);
        head.appendChild(orb);
        var headInfo = el('div', 'cpchat-head-info');
        headInfo.appendChild(el('b', '', cfg.title || 'Chat with us'));
        els.state = el('span', 'cpchat-state', '');
        headInfo.appendChild(els.state);
        head.appendChild(headInfo);
        els.endBtn = el('button', 'cpchat-new-btn', 'New chat');
        els.endBtn.setAttribute('type', 'button');
        els.endBtn.style.display = 'none';
        els.endBtn.onclick = endChat;
        var gridBtn = el('button', 'cpchat-icon-btn', '');
        gridBtn.type = 'button';
        gridBtn.title = 'Quick menu';
        gridBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor"><circle cx="3" cy="3" r="1.4"/><circle cx="8" cy="3" r="1.4"/><circle cx="13" cy="3" r="1.4"/><circle cx="3" cy="8" r="1.4"/><circle cx="8" cy="8" r="1.4"/><circle cx="13" cy="8" r="1.4"/><circle cx="3" cy="13" r="1.4"/><circle cx="8" cy="13" r="1.4"/><circle cx="13" cy="13" r="1.4"/></svg>';
        var closeBtn = el('button', 'cpchat-icon-btn', '');
        closeBtn.setAttribute('type', 'button');
        closeBtn.title = 'Close';
        closeBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg>';
        closeBtn.onclick = closePanel;
        head.appendChild(els.endBtn);
        head.appendChild(gridBtn);
        head.appendChild(closeBtn);

        els.body = el('div', 'cpchat-body');
        els.typing = el('div', 'cpchat-typing', '');
        els.typing.innerHTML = '<div class="cpchat-typing-dots"><span></span><span></span><span></span></div>';
        els.rateBar = el('div', 'cpchat-rate');
        els.rateBar.appendChild(el('span', '', 'Was this helpful?'));
        var rateBtns = el('div', '');
        rateBtns.style.display = 'flex';
        rateBtns.style.gap = '6px';
        var rYes = el('button', '', '\ud83d\udc4d Yes');
        rYes.type = 'button';
        rYes.onclick = function () { sendRating(5); };
        var rNo = el('button', '', '\ud83d\udc4e No');
        rNo.type = 'button';
        rNo.onclick = function () { sendRating(1); };
        rateBtns.appendChild(rYes);
        rateBtns.appendChild(rNo);
        els.rateBar.appendChild(rateBtns);
        els.note = el('div', 'cpchat-note', '');

        var fileIn = document.createElement('input');
        fileIn.type = 'file';
        fileIn.accept = '.jpg,.jpeg,.png,.webp,.pdf,.txt,.mp3,.m4a,.wav,.ogg,.webm';
        fileIn.style.display = 'none';
        fileIn.onchange = function () {
            if (fileIn.files && fileIn.files[0]) {
                uploadFile(fileIn.files[0], '');
                fileIn.value = '';
            }
        };

        var attachBtn = el('button', 'cpchat-icon-btn', '');
        attachBtn.type = 'button';
        attachBtn.title = 'Attach image, PDF, or audio';
        attachBtn.innerHTML = '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/></svg>';
        attachBtn.onclick = function () { fileIn.click(); };

        var micBtn = el('button', 'cpchat-icon-btn', '');
        micBtn.type = 'button';
        micBtn.title = 'Record voice message';
        micBtn.innerHTML = '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg>';

        var sendBtn = el('button', 'cpchat-send-btn', '');
        sendBtn.setAttribute('type', 'button');
        sendBtn.title = 'Send';
        sendBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>';
        sendBtn.onclick = function () {
            sendMessage();
            sendBtn.className = 'cpchat-send-btn';
        };

        els.input = document.createElement('textarea');
        els.input.placeholder = 'Type here\u2026';
        els.input.setAttribute('rows', '1');
        els.input.maxLength = maxLength;
        els.input.oninput = function () {
            autosize();
            pingTyping();
            var hasTxt = els.input.value.replace(/\s+/g, '') !== '';
            sendBtn.className = 'cpchat-send-btn' + (hasTxt ? ' on' : '');
        };
        els.input.onkeydown = function (ev) {
            if (ev && ev.key === 'Enter' && !ev.shiftKey) {
                ev.preventDefault();
                sendMessage();
                sendBtn.className = 'cpchat-send-btn';
            }
        };

        var recBar = el('div', 'cpchat-rec-bar', '');
        var recLabel = el('span', '', '\u25cf Recording 0:00');
        var recBtns = el('div', '');
        recBtns.style.display = 'flex';
        recBtns.style.gap = '6px';
        var recCancel = el('button', '', 'Cancel');
        recCancel.type = 'button';
        recCancel.style.background = '#fff';
        recCancel.style.color = '#374151';
        var recSend = el('button', '', 'Send Voice');
        recSend.type = 'button';
        recSend.style.background = '#111827';
        recSend.style.color = '#fff';
        recBtns.appendChild(recCancel);
        recBtns.appendChild(recSend);
        recBar.appendChild(recLabel);
        recBar.appendChild(recBtns);

        var foot = el('div', 'cpchat-foot');
        foot.appendChild(fileIn);
        foot.appendChild(attachBtn);
        foot.appendChild(els.input);
        foot.appendChild(micBtn);
        foot.appendChild(sendBtn);

        var footWrap = el('div', 'cpchat-foot-wrap');
        footWrap.appendChild(recBar);
        footWrap.appendChild(foot);

        var recState = { rec: null, chunks: [], timer: null, sec: 0, stream: null };
        function stopRec(sendAudio) {
            clearInterval(recState.timer);
            recBar.className = 'cpchat-rec-bar';
            foot.style.display = 'flex';
            if (recState.rec && recState.rec.state !== 'inactive') {
                recState.rec.onstop = function () {
                    if (recState.stream) {
                        recState.stream.getTracks().forEach(function (t) { t.stop(); });
                    }
                    if (sendAudio && recState.chunks.length) {
                        var mime = recState.rec.mimeType || 'audio/webm';
                        var ext = mime.indexOf('mp4') !== -1 ? 'm4a' : (mime.indexOf('ogg') !== -1 ? 'ogg' : 'webm');
                        var blob = new Blob(recState.chunks, { type: mime });
                        uploadFile(blob, 'voice-message.' + ext);
                    }
                    recState.chunks = [];
                };
                recState.rec.stop();
            }
        }
        recCancel.onclick = function () { stopRec(false); };
        recSend.onclick = function () { stopRec(true); };
        micBtn.onclick = function () {
            if (!state.token || state.status !== 'open') { return; }
            if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || !window.MediaRecorder) {
                note('Voice recording requires HTTPS and a modern browser.');
                setTimeout(function () { note(''); }, 4000);
                return;
            }
            navigator.mediaDevices.getUserMedia({ audio: true }).then(function (stream) {
                recState.stream = stream;
                recState.chunks = [];
                recState.sec = 0;
                recState.rec = new MediaRecorder(stream);
                recState.rec.ondataavailable = function (e) {
                    if (e.data && e.data.size > 0) { recState.chunks.push(e.data); }
                };
                recState.rec.start();
                foot.style.display = 'none';
                recBar.className = 'cpchat-rec-bar on';
                recLabel.textContent = '\u25cf Recording 0:00';
                recState.timer = setInterval(function () {
                    recState.sec++;
                    var mm = Math.floor(recState.sec / 60);
                    var ss = ('0' + (recState.sec % 60)).slice(-2);
                    recLabel.textContent = '\u25cf Recording ' + mm + ':' + ss;
                    if (recState.sec >= 60) { stopRec(true); }
                }, 1000);
            }).catch(function () {
                note('Microphone permission denied or unavailable on HTTP.');
                setTimeout(function () { note(''); }, 4000);
            });
        };

        function uploadFile(file, customName) {
            if (!state.token || !urls.upload || state.status !== 'open') { return; }
            if (file.size > 2 * 1024 * 1024) {
                note('File must be under 2 MB.');
                setTimeout(function () { note(''); }, 4000);
                return;
            }
            var ref = uuid();
            var fd = new FormData();
            fd.append('token', state.token);
            fd.append('ref', ref);
            if (customName) {
                fd.append('file', file, customName);
            } else {
                fd.append('file', file);
            }
            note('Uploading attachment\u2026');
            var x = new XMLHttpRequest();
            x.open('POST', urls.upload, true);
            x.onreadystatechange = function () {
                if (x.readyState !== 4) { return; }
                note('');
                var res = null;
                try { res = JSON.parse(x.responseText); } catch (e) { res = null; }
                if (!res || !res.success) {
                    note((res && res.message) ? res.message : 'Upload failed');
                    setTimeout(function () { note(''); }, 4000);
                    return;
                }
                if (res.id > state.seen) {
                    state.seen = res.id;
                    store.set('cpchat_seen', String(state.seen));
                }
                state.rendered[res.id] = true;
                els.body.appendChild(bubble({
                    id: res.id,
                    sender: 'customer',
                    body: customName ? 'Voice message' : (file.name || ''),
                    attachment: res.attachment,
                    time: timeStr()
                }));
                scrollBottom();
            };
            x.send(fd);
        }

        els.chat = el('div', '');
        els.chat.style.display = 'none';
        els.chat.style.flex = '1';
        els.chat.style.flexDirection = 'column';
        els.chat.style.minHeight = '0';
        var chatQuick = buildQuickBar(els.chat);
        gridBtn.onclick = function () {
            if (els.chat.style.display !== 'none' && chatQuick) {
                chatQuick.style.display = (chatQuick.style.display === 'none') ? 'flex' : 'none';
            } else {
                openFaqs();
            }
        };
        els.chatOffline = el('div', 'cpchat-offline', '');
        els.chatOffline.style.margin = '8px 12px 0';
        els.chatOffline.appendChild(el('b', '', (cfg.hours && cfg.hours.length) ? cfg.hours : 'Offline'));
        els.chatOffline.appendChild(document.createTextNode(cfg.awayMessage || 'We are offline right now, leave your question and we will reply as soon as we are back.'));
        els.chatOffline.style.display = 'none';
        els.chat.appendChild(els.chatOffline);
        els.chat.appendChild(els.body);
        els.chat.appendChild(els.typing);
        els.chat.appendChild(els.rateBar);
        els.chat.appendChild(els.note);
        els.chat.appendChild(footWrap);

        els.form = el('div', 'cpchat-form');
        els.form.style.display = 'none';
        els.form.appendChild(el('div', 'cpchat-sys', cfg.welcome || ''));
        buildQuickBar(els.form);
        els.helperArea = el('div', '');
        els.form.appendChild(els.helperArea);
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
        els.startBtn = el('button', 'cpchat-start-btn', 'Start chat');
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
            document.addEventListener('visibilitychange', function () {
                if (!document.hidden && state.token) {
                    poll(false);
                    tick();
                }
            });
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
            if (els.orbDot) { els.orbDot.className = 'cpchat-orb-dot'; }
            if (els.chatOffline) { els.chatOffline.style.display = 'none'; }
            if (els.offline) { els.offline.style.display = 'none'; }
        } else {
            els.state.className = 'cpchat-state off';
            els.state.textContent = (cfg.hours && cfg.hours.length) ? cfg.hours : 'Offline';
            if (els.orbDot) { els.orbDot.className = 'cpchat-orb-dot off'; }
            if (els.chatOffline) { els.chatOffline.style.display = 'block'; }
            if (els.offline) { els.offline.style.display = 'block'; }
        }
    }

    build();

    window.CPCHAT = {
        open: openPanel,
        close: closePanel,
        state: state
    };
})();
