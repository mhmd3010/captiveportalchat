{include file="sections/header.tpl"}

<div class="cp-page cp-inbox-page">
    <div class="cp-head">
        <div class="cp-head-title">
            <h2><i class="fa fa-inbox" style="color:#2563eb;margin-right:6px;"></i> {Lang::T('Inbox')}</h2>
            {if $open_now}
                <span class="cp-pill cp-pill-ok"><i class="fa fa-circle" style="font-size:8px;"></i> {Lang::T('Online')}</span>
            {else}
                <span class="cp-pill cp-pill-warn" title="{$hours_label|escape:'html'}"><i class="fa fa-moon-o"></i> {Lang::T('Offline')}</span>
            {/if}
            <span class="cp-pill cp-pill-info">{Lang::T('Open')}: {$stats.open|default:0}</span>
            <span class="cp-pill cp-pill-warn">{Lang::T('Waiting')}: {$stats.waiting|default:0}</span>
            <span class="cp-pill cp-pill-bad">{Lang::T('Unread')}: {$stats.unread|default:0}</span>
        </div>
        <div class="cp-head-actions">
            <a href="{$_url}plugin/captivePortalChat" class="cp-btn"><i class="fa fa-dashboard"></i> {Lang::T('Dashboard')}</a>
            {if $can_manage}
                <a href="{$_url}plugin/captivePortalChatSettings" class="cp-btn"><i class="fa fa-cog"></i> {Lang::T('Settings')}</a>
                <a href="{$_url}plugin/captivePortalChatSettings#tabCanned" class="cp-btn"><i class="fa fa-reply"></i> {Lang::T('Canned replies')}</a>
            {/if}
        </div>
    </div>

    {if $install_error neq ''}
        <div class="cp-banner cp-banner-bad">
            <span>{Lang::T('Chat tables could not be created')}: {$install_error|escape:'html'}</span>
        </div>
    {/if}
    {if !$open_now && $s.hours_enabled}
        <div class="cp-banner cp-banner-info">
            <span><i class="fa fa-clock-o"></i> {Lang::T('Outside support hours')} &mdash; {$hours_label|escape:'html'}. {Lang::T('Customers see the away message until the team is back.')}</span>
        </div>
    {/if}

    <div class="cp-split">
        <div id="cpchatListView" class="cp-split-list">
            <div class="cp-card" style="margin-bottom:0;">
                <div class="cp-card-head" style="display:block;">
                    <input type="text" id="cpchatSearch" class="form-control input-sm"
                        value="{$filters.q|escape:'html'}" placeholder="{Lang::T('Search name, phone, mac, ip, tag or message')}">
                    <div class="cp-filters">
                        <select id="cpchatStatus" class="form-control input-sm">
                            <option value="">{Lang::T('Any status')}</option>
                            <option value="open" {if $filters.status eq 'open'}selected{/if}>{Lang::T('Open only')}</option>
                            <option value="closed" {if $filters.status eq 'closed'}selected{/if}>{Lang::T('Closed only')}</option>
                        </select>
                        <select id="cpchatAssigned" class="form-control input-sm">
                            <option value="">{Lang::T('Everyone')}</option>
                            <option value="unassigned" {if $filters.assigned eq 'unassigned'}selected{/if}>{Lang::T('Unassigned')}</option>
                            <option value="me" {if $filters.assigned eq 'me'}selected{/if}>{Lang::T('Assigned to me')}</option>
                            {foreach $agents as $a}
                                <option value="{$a.id}" {if $filters.assigned eq $a.id}selected{/if}>{$a.name|escape:'html'}</option>
                            {/foreach}
                        </select>
                        <select id="cpchatRouter" class="form-control input-sm">
                            <option value="">{Lang::T('All routers')}</option>
                            {foreach $routers as $r}
                                <option value="{$r|escape:'html'}" {if $filters.router eq $r}selected{/if}>{$r|escape:'html'}</option>
                            {/foreach}
                        </select>
                        <select id="cpchatTag" class="form-control input-sm">
                            <option value="">{Lang::T('All tags')}</option>
                            {foreach $tagOptions as $t}
                                <option value="{$t|escape:'html'}" {if $filters.tag eq $t}selected{/if}>{$t|escape:'html'}</option>
                            {/foreach}
                        </select>
                    </div>
                    <div style="display:flex;align-items:center;justify-content:space-between;margin-top:8px;font-weight:500;font-size:12px;">
                        <label style="margin:0;cursor:pointer;display:inline-flex;align-items:center;gap:5px;">
                            <input type="checkbox" id="cpchatSpam" value="1"> {Lang::T('Spam')}
                        </label>
                        <div style="display:flex;gap:4px;">
                            <button type="button" class="cp-btn cp-btn-sm" id="cpchatExportCsv" title="{Lang::T('Export this list as CSV')}"><i class="fa fa-file-text-o"></i> CSV</button>
                            <button type="button" class="cp-btn cp-btn-sm" id="cpchatExportPdf" title="{Lang::T('Export this list as PDF')}"><i class="fa fa-file-pdf-o"></i> PDF</button>
                        </div>
                    </div>
                </div>
                <div id="cpchatList" class="cp-conv-list">
                    {foreach $conversations as $c}
                        <a href="#" class="cp-conv-item cpchat-conv{if $c.id eq $active_id} is-active{/if}{if $c.is_spam} is-spam{/if}" data-id="{$c.id}">
                            <div class="cp-conv-top">
                                <strong>{$c.name|escape:'html'} <small style="font-weight:500;color:var(--cpchat-text-muted);">{$c.phone|escape:'html'}</small></strong>
                                <small style="color:var(--cpchat-text-muted);white-space:nowrap;">{$c.last_ago|escape:'html'}</small>
                            </div>
                            <div class="cp-conv-sub">
                                {if $c.username neq ''}<i class="fa fa-user"></i> {$c.username|escape:'html'} &middot; {/if}
                                {if $c.mac neq ''}<i class="fa fa-wifi"></i> {$c.mac|escape:'html'}{/if}
                                {if $c.router neq ''} &middot; <i class="fa fa-server"></i> {$c.router|escape:'html'}{/if}
                            </div>
                            {if $c.tags|@count > 0 || $c.assigned_name neq '' || $c.is_spam || $c.close_reason neq ''}
                                <div style="margin-top:4px;display:flex;flex-wrap:wrap;gap:3px;">
                                    {foreach $c.tags as $t}<span class="label label-default">{$t|escape:'html'}</span>{/foreach}
                                    {if $c.assigned_name neq ''}<span class="label label-info"><i class="fa fa-headphones"></i> {$c.assigned_name|escape:'html'}</span>{/if}
                                    {if $c.is_spam}<span class="label label-danger">{Lang::T('Spam')}</span>{/if}
                                    {if $c.close_reason neq ''}<span class="label label-warning">{$c.close_reason|escape:'html'}</span>{/if}
                                </div>
                            {/if}
                            <div class="cp-conv-preview">
                                {if $c.unread_admin > 0}<span class="badge bg-red">{$c.unread_admin}</span>{/if}
                                <span style="overflow:hidden;text-overflow:ellipsis;">{$c.last_body|escape:'html'|truncate:60}</span>
                            </div>
                        </a>
                    {/foreach}
                    {if $conversations|@count eq 0}
                        <div style="padding:28px 16px;text-align:center;color:var(--cpchat-text-muted);font-size:13px;">{Lang::T('No chats match these filters.')}</div>
                    {/if}
                </div>
            </div>
        </div>

        <div id="cpchatThreadView" class="cp-split-thread" style="display:none;">
            <div class="cp-card" style="margin-bottom:0;">
                <div class="cp-card-head">
                    <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
                        <button type="button" class="cp-btn cp-btn-sm cp-back-btn" id="cpchatBackBtn"><i class="fa fa-arrow-left"></i> {Lang::T('Back')}</button>
                        <span id="cpchatThreadTitle" style="font-size:15px;font-weight:700;">
                            {if $active}
                                {$active.name|escape:'html'} <small style="font-weight:500;color:var(--cpchat-text-muted);">{$active.phone|escape:'html'}</small>
                            {else}
                                {Lang::T('Select a chat')}
                            {/if}
                        </span>
                        <span class="label label-default" id="cpchatThreadStatus">{if $active}{$active.status}{else}&ndash;{/if}</span>
                    </div>
                    <div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;">
                        <select id="cpchatAssign" class="form-control input-sm" style="width:auto;max-width:150px;" disabled>
                            <option value="0">{Lang::T('Unassigned')}</option>
                            <option value="me">{Lang::T('Assign to me')}</option>
                            {foreach $agents as $a}
                                <option value="{$a.id}">{$a.name|escape:'html'}</option>
                            {/foreach}
                        </select>
                        <button type="button" class="cp-btn cp-btn-sm" id="cpchatTagBtn" disabled title="{Lang::T('Edit tags')}"><i class="fa fa-tag"></i></button>
                        <div class="btn-group" style="display:inline-block;">
                            <button type="button" class="cp-btn cp-btn-sm dropdown-toggle" id="cpchatMoreBtn" disabled data-bs-toggle="dropdown" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                                <i class="fa fa-ellipsis-h"></i>
                            </button>
                            <ul class="dropdown-menu dropdown-menu-end dropdown-menu-right">
                                <li><a class="dropdown-item" href="#" id="cpchatSpamBtn"><i class="fa fa-ban"></i> {Lang::T('Mark as spam')}</a></li>
                                {if $can_manage}<li><a class="dropdown-item" href="#" id="cpchatBlockBtn"><i class="fa fa-user-times"></i> {Lang::T('Block this visitor')}</a></li>{/if}
                                <li role="separator" class="divider dropdown-divider"></li>
                                <li><a class="dropdown-item" href="#" id="cpchatChatCsv"><i class="fa fa-file-text-o"></i> {Lang::T('Transcript CSV')}</a></li>
                                <li><a class="dropdown-item" href="#" id="cpchatChatPdf"><i class="fa fa-file-pdf-o"></i> {Lang::T('Transcript PDF')}</a></li>
                            </ul>
                        </div>
                        <button type="button" class="cp-btn cp-btn-primary cp-btn-sm" id="cpchatToggleStatus" {if !$active}disabled{/if}>
                            {if $active}{if $active.status eq 'open'}{Lang::T('Close')}{else}{Lang::T('Reopen')}{/if}{else}{Lang::T('Close')}{/if}
                        </button>
                    </div>
                </div>

                <div class="cp-meta-bar" id="cpchatMetaBar"{if !$active} style="display:none;"{/if}>
                    {if $active}
                        <span class="cp-meta-chip"><i class="fa fa-mobile"></i> {Lang::T('Phone')}: <b>{$active.phone|escape:'html'}</b></span>
                        <span class="cp-meta-chip"><i class="fa fa-user"></i> {Lang::T('Name')}: <b>{$active.name|escape:'html'}</b></span>
                        {if $active.mac neq ''}<span class="cp-meta-chip"><i class="fa fa-wifi"></i> MAC: <b>{$active.mac|escape:'html'}</b></span>{/if}
                        {if $active.ip neq ''}<span class="cp-meta-chip"><i class="fa fa-globe"></i> IP: <b>{$active.ip|escape:'html'}</b></span>{/if}
                        {if $active.username neq ''}<span class="cp-meta-chip"><i class="fa fa-sign-in"></i> {Lang::T('Username')}: <b>{$active.username|escape:'html'}</b></span>{/if}
                        {if $active.router neq ''}<span class="cp-meta-chip"><i class="fa fa-server"></i> {Lang::T('Router')}: <b>{$active.router|escape:'html'}</b></span>{/if}
                        {if $active.page neq ''}<span class="cp-meta-chip"><i class="fa fa-file-o"></i> {Lang::T('Page')}: <b>{$active.page|escape:'html'}</b></span>{/if}
                        <span class="cp-meta-chip"><i class="fa fa-clock-o"></i> {Lang::T('Created')}: <b>{Lang::dateTimeFormat($active.created_at)}</b></span>
                    {/if}
                </div>

                <div id="cpchatCustomerBox" class="cp-customer-bar{if !$active_customer} is-guest{/if}"{if !$active} style="display:none;"{/if}>
                    {if $active_customer}
                        <div class="cp-customer-info">
                            <span><i class="fa fa-id-card-o"></i> <b>{$active_customer.fullname|escape:'html'}</b> (<code>{$active_customer.username|escape:'html'}</code>)</span>
                            <span>{Lang::T('Plan')}: <b>{$active_customer.plan|default:'-'|escape:'html'}</b></span>
                            <span class="label {if $active_customer.status eq 'on'}label-success{else}label-default{/if}">{if $active_customer.status eq 'on'}{Lang::T('Active')}{else}{$active_customer.status|default:'-'|escape:'html'}{/if}</span>
                            {if $active_customer.expiration neq ''}<span>{Lang::T('Expires')}: <b>{$active_customer.expiration|escape:'html'}</b></span>{/if}
                        </div>
                        <a href="{$active_customer.url|escape:'html'}" target="_blank" class="cp-btn cp-btn-sm"><i class="fa fa-external-link"></i> {Lang::T('Profile')}</a>
                    {elseif $active}
                        <span><i class="fa fa-user-secret"></i> {Lang::T('Guest / Unregistered visitor')}</span>
                    {/if}
                </div>

                <div id="cpchatThread" class="cp-thread">
                    {if $active}
                        {foreach $thread as $m}
                            {if $m.sender eq 'system'}
                                <div class="text-center" style="margin:6px 0;">
                                    <small style="color:var(--cpchat-text-muted);">{$m.body|escape:'html'|nl2br}</small>
                                </div>
                            {elseif $m.sender eq 'note'}
                                <div class="text-right" style="margin-bottom:10px;">
                                    <div class="cp-note-bubble">
                                        <small style="display:block;font-weight:700;margin-bottom:2px;"><i class="fa fa-sticky-note-o"></i> {Lang::T('Internal Note')}</small>
                                        {$m.body|escape:'html'|nl2br}
                                        <small style="display:block;margin-top:4px;opacity:.75;">{if $m.sender_name neq ''}{$m.sender_name|escape:'html'} · {/if}{$m.time}</small>
                                    </div>
                                </div>
                            {else}
                                <div class="{if $m.sender eq 'admin'}text-right{/if}" style="margin-bottom:10px;">
                                    <div class="well well-sm{if $m.sender eq 'admin'} cpchat-admin-bubble{/if}" style="display:inline-block;max-width:78%;text-align:left;margin:0;word-break:break-word;">
                                        {$m.body|escape:'html'|nl2br}
                                        <small style="display:block;margin-top:4px;opacity:.75;">{if $m.sender eq 'admin' && $m.sender_name neq ''}{$m.sender_name|escape:'html'} · {/if}{$m.time}</small>
                                    </div>
                                </div>
                            {/if}
                        {/foreach}
                    {else}
                        <div style="padding:48px 16px;text-align:center;color:var(--cpchat-text-muted);">
                            <i class="fa fa-comments-o" style="font-size:38px;display:block;margin-bottom:10px;opacity:.5;"></i>
                            {Lang::T('Select a chat from the list.')}
                        </div>
                    {/if}
                </div>
                <div id="cpchatTyping" class="cp-typing">Typing &hellip;</div>

                <div class="cp-composer">
                    <div id="cpchatSlashMenu" class="cp-slash-menu"></div>
                    <div class="cp-composer-top">
                        <div class="cp-mode-group">
                            <button type="button" class="cp-mode-btn active" id="cpchatModeReply">{Lang::T('Reply')}</button>
                            <button type="button" class="cp-mode-btn note" id="cpchatModeNote"><i class="fa fa-sticky-note-o"></i> {Lang::T('Internal Note')}</button>
                        </div>
                        <select id="cpchatCanned" class="form-control input-sm" style="width:220px;max-width:100%;" disabled>
                            <option value="">{Lang::T('Canned replies (/ to search)')}…</option>
                            {foreach $canned as $k}
                                <option value="{$k.body|escape:'html'}">{$k.title|escape:'html'|truncate:48}</option>
                            {/foreach}
                        </select>
                        <span id="cpchatTagList" style="display:flex;flex-wrap:wrap;gap:4px;">
                            {if $active}{foreach $active.tags as $t}<span class="label label-default">{$t|escape:'html'}</span>{/foreach}{/if}
                        </span>
                    </div>
                    <div class="cp-composer-bar">
                        <textarea id="cpchatReply" class="form-control" rows="2"
                            placeholder="{Lang::T('Type your reply, Enter to send')}"{if !$active} disabled{/if}></textarea>
                        <button type="button" class="cp-btn cp-btn-primary" id="cpchatSendReply"{if !$active} disabled{/if}>
                            <i class="fa fa-paper-plane"></i> {Lang::T('Reply')}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

{literal}
<script>
(function () {
    'use strict';
    var cfg = window.CPCHAT_ADMIN || {};
    var urls = cfg.urls || {};
    var listEl = document.getElementById('cpchatList');
    var threadEl = document.getElementById('cpchatThread');
    var titleEl = document.getElementById('cpchatThreadTitle');
    var statusEl = document.getElementById('cpchatThreadStatus');
    var metaEl = document.getElementById('cpchatMetaBar');
    var searchEl = document.getElementById('cpchatSearch');
    var statusFilter = document.getElementById('cpchatStatus');
    var assignedFilter = document.getElementById('cpchatAssigned');
    var routerFilter = document.getElementById('cpchatRouter');
    var tagFilter = document.getElementById('cpchatTag');
    var spamFilter = document.getElementById('cpchatSpam');
    var replyEl = document.getElementById('cpchatReply');
    var sendBtn = document.getElementById('cpchatSendReply');
    var toggleBtn = document.getElementById('cpchatToggleStatus');
    var assignEl = document.getElementById('cpchatAssign');
    var tagBtn = document.getElementById('cpchatTagBtn');
    var tagListEl = document.getElementById('cpchatTagList');
    var cannedEl = document.getElementById('cpchatCanned');
    var moreBtn = document.getElementById('cpchatMoreBtn');
    var listView = document.getElementById('cpchatListView');
    var threadView = document.getElementById('cpchatThreadView');
    var backBtn = document.getElementById('cpchatBackBtn');
    var customerBox = document.getElementById('cpchatCustomerBox');
    var typingEl = document.getElementById('cpchatTyping');
    var slashMenu = document.getElementById('cpchatSlashMenu');
    var modeReplyBtn = document.getElementById('cpchatModeReply');
    var modeNoteBtn = document.getElementById('cpchatModeNote');
    var replyMode = 'admin';
    var activeConv = null;
    var activeCustomer = null;
    var lastAdminTyping = 0;
    var activeId = parseInt('{/literal}{$active_id}{literal}', 10) || 0;
    var lastId = parseInt('{/literal}{$thread_last_id}{literal}', 10) || 0;
    var activeStatus = '{/literal}{if $active}{$active.status}{/if}{literal}';
    var activeTags = {/literal}{if $active}{$active.tags|@json_encode}{else}[]{/if}{literal} || [];
    var closeReasons = cfg.closeReasons || [];
    var tagOptions = cfg.tags || [];
    var listTimer = null, threadTimer = null, searchTimer = null;
    var pollEvery = (cfg.poll || 15) * 1000;

    function param(url, key, value) {
        return url + (url.indexOf('?') === -1 ? '?' : '&') + encodeURIComponent(key) + '=' + encodeURIComponent(value);
    }

    function get(url, cb) {
        var x = new XMLHttpRequest();
        x.open('GET', url, true);
        x.timeout = 20000;
        x.onreadystatechange = function () {
            if (x.readyState === 4) {
                cb(x.status === 0 ? null : (function () { try { return JSON.parse(x.responseText); } catch (e) { return null; } })());
            }
        };
        x.ontimeout = function () { cb(null); };
        x.onerror = function () { cb(null); };
        x.send();
    }

    function post(url, data, cb) {
        var body = [];
        for (var k in data) {
            if (Object.prototype.hasOwnProperty.call(data, k)) {
                body.push(encodeURIComponent(k) + '=' + encodeURIComponent(data[k]));
            }
        }
        var x = new XMLHttpRequest();
        x.open('POST', url, true);
        x.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
        x.timeout = 20000;
        x.onreadystatechange = function () {
            if (x.readyState === 4) {
                var j = null;
                try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
                cb(j);
            }
        };
        x.ontimeout = function () { cb(null); };
        x.onerror = function () { cb(null); };
        x.send(body.join('&'));
    }

    function esc(t) {
        var d = document.createElement('div');
        d.appendChild(document.createTextNode(t === null || t === undefined ? '' : String(t)));
        return d.innerHTML.replace(/\n/g, '<br>');
    }

    function toast(msg, bad) {
        if (window.Swal) {
            Swal.fire({
                icon: bad ? 'error' : 'success',
                title: msg,
                position: 'top-end',
                showConfirmButton: false,
                timer: 5000,
                timerProgressBar: true,
                didOpen: function (t) {
                    t.addEventListener('mouseenter', Swal.stopTimer);
                    t.addEventListener('mouseleave', Swal.resumeTimer);
                }
            });
        }
    }

    function filters() {
        var f = {};
        if (searchEl.value) { f.q = searchEl.value; }
        if (statusFilter.value) { f.status = statusFilter.value; }
        if (assignedFilter.value) { f.assigned = assignedFilter.value; }
        if (routerFilter.value) { f.router = routerFilter.value; }
        if (tagFilter.value) { f.tag = tagFilter.value; }
        if (spamFilter.checked) { f.spam = '1'; }
        return f;
    }

    function filterUrl(base) {
        var f = filters(), url = base;
        for (var k in f) {
            if (Object.prototype.hasOwnProperty.call(f, k)) {
                url = param(url, k, f[k]);
            }
        }
        return url;
    }

    function renderList(conversations) {
        var html = '';
        for (var i = 0; i < conversations.length; i++) {
            var c = conversations[i];
            var cls = 'list-group-item cpchat-conv';
            if (c.id === activeId) { cls += ' list-group-item-info'; }
            if (c.is_spam) { cls += ' list-group-item-danger'; }
            var sub = '';
            if (c.username) { sub += '<small class="text-muted"><i class="fa fa-user"></i> ' + esc(c.username) + '</small> &nbsp;'; }
            if (c.mac) { sub += '<small class="text-muted"><i class="fa fa-wifi"></i> ' + esc(c.mac) + '</small>'; }
            if (c.router) { sub += ' &nbsp;<small class="text-muted"><i class="fa fa-server"></i> ' + esc(c.router) + '</small>'; }
            var flags = '';
            (c.tags || []).forEach(function (t) { flags += '<span class="label label-default">' + esc(t) + '</span> '; });
            if (c.assigned_name) { flags += '<span class="label label-info"><i class="fa fa-headphones"></i> ' + esc(c.assigned_name) + '</span> '; }
            if (c.is_spam) { flags += '<span class="label label-danger">Spam</span> '; }
            if (c.close_reason) { flags += '<span class="label label-warning">' + esc(c.close_reason) + '</span>'; }
            html += '<a href="#" class="' + cls + '" data-id="' + c.id + '">'
                + '<div class="pull-right"><small class="text-muted">' + esc(c.last_ago) + '</small></div>'
                + '<strong>' + esc(c.name) + '</strong> <small class="text-muted">' + esc(c.phone) + '</small>'
                + '<div style="clear:both;">' + sub + '</div>'
                + (flags ? '<div style="margin-top:3px;">' + flags + '</div>' : '')
                + '<div style="margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">'
                + (c.unread_admin > 0 ? '<span class="badge bg-red">' + c.unread_admin + '</span> ' : '')
                + '<small>' + esc(c.last_body) + '</small></div></a>';
        }
        if (!conversations.length) {
            html = '<div class="list-group-item text-center text-muted">No chats match these filters.</div>';
        }
        listEl.innerHTML = html;
    }

    function loadList() {
        get(filterUrl(urls.threads), function (res) {
            if (res && res.success) {
                renderList(res.conversations || []);
                bindList();
            }
            scheduleList();
        });
    }

    function scheduleList() {
        clearTimeout(listTimer);
        listTimer = setTimeout(loadList, document.hidden ? pollEvery * 2 : pollEvery);
    }

    function bindList() {
        var nodes = listEl.querySelectorAll('.cpchat-conv');
        for (var i = 0; i < nodes.length; i++) {
            nodes[i].onclick = function (ev) {
                ev.preventDefault();
                openThread(parseInt(this.getAttribute('data-id'), 10));
            };
        }
    }

    function openThread(id) {
        if (!id) { return; }
        activeId = id;
        lastId = 0;
        var nodes = listEl.querySelectorAll('.cpchat-conv');
        for (var i = 0; i < nodes.length; i++) {
            nodes[i].className = nodes[i].className.replace(/ list-group-item-info/g, '')
                + (parseInt(nodes[i].getAttribute('data-id'), 10) === id ? ' list-group-item-info' : '');
        }
        showThread();
        setCompose(true);
        get(param(urls.thread, 'id', id), function (res) {
            if (!res || !res.success) {
                setCompose(false);
                return;
            }
            renderThreadShell(res.conversation);
            renderCustomerBox(res.customer || null);
            if (typingEl) { typingEl.style.display = res.customer_typing ? 'block' : 'none'; }
            threadEl.innerHTML = '';
            appendMessages(res.messages);
            lastId = res.last_id || 0;
            pollThreadNow();
        });
    }

    function setCompose(on) {
        [replyEl, sendBtn, toggleBtn, assignEl, tagBtn, cannedEl, moreBtn].forEach(function (node) {
            if (node) {
                node.disabled = !on;
            }
        });
        if (on && replyEl) {
            replyEl.focus();
        }
    }

    function showList() {
        listView.style.display = '';
        threadView.style.display = 'none';
        clearTimeout(threadTimer);
    }

    function showThread() {
        threadView.style.display = '';
        listView.style.display = 'none';
    }

    if (backBtn) {
        backBtn.onclick = function () { showList(); loadListSoon(); };
    }

    function paintTags() {
        if (!tagListEl) { return; }
        tagListEl.innerHTML = (activeTags || []).map(function (t) {
            return '<span class="label label-default">' + esc(t) + '</span> ';
        }).join('');
    }

    function renderThreadShell(c) {
        activeConv = c;
        activeStatus = c.status;
        activeTags = c.tags || [];
        titleEl.innerHTML = esc(c.name) + ' <small>' + esc(c.phone) + '</small>'
            + (c.is_spam ? ' <span class="label label-danger">Spam</span>' : '');
        statusEl.className = 'label ' + (c.status === 'open' ? 'label-success' : 'label-default');
        statusEl.innerHTML = esc(c.status) + (c.close_reason ? ' · ' + esc(c.close_reason) : '');
        if (assignEl) {
            assignEl.value = (c.assigned_to && assignEl.querySelector('option[value="' + c.assigned_to + '"]')) ? String(c.assigned_to) : '0';
        }
        if (toggleBtn) {
            toggleBtn.innerHTML = esc(c.status === 'open' ? 'Close' : 'Reopen');
        }
        paintTags();
        var cells = [];
        cells.push(metaCell('fa-mobile', 'Phone', c.phone));
        cells.push(metaCell('fa-user', 'Name', c.name));
        if (c.mac) { cells.push(metaCell('fa-wifi', 'MAC', c.mac)); }
        if (c.ip) { cells.push(metaCell('fa-globe', 'IP', c.ip)); }
        if (c.username) { cells.push(metaCell('fa-sign-in', 'Username', c.username)); }
        if (c.router) { cells.push(metaCell('fa-server', 'Router', c.router)); }
        if (c.page) { cells.push(metaCell('fa-file-o', 'Page', c.page)); }
        cells.push(metaCell('fa-clock-o', 'Created', (c.created_dt || c.created_at)));
        metaEl.innerHTML = cells.join('');
        metaEl.style.display = '';
    }

    function metaCell(icon, label, value) {
        return '<span class="cp-meta-chip"><i class="fa ' + icon + '"></i> ' + esc(label) + ': <b>' + esc(value) + '</b></span>';
    }

    function renderCustomerBox(cust) {
        activeCustomer = cust;
        if (!customerBox) { return; }
        customerBox.style.display = '';
        if (cust) {
            customerBox.className = 'cp-customer-bar';
            var stCls = cust.status === 'on' ? 'label-success' : 'label-default';
            var stTxt = cust.status === 'on' ? 'Active' : (cust.status || '-');
            customerBox.innerHTML = '<div class="cp-customer-info">'
                + '<span><i class="fa fa-id-card-o"></i> <b>' + esc(cust.fullname || cust.username) + '</b> (<code>' + esc(cust.username) + '</code>)</span>'
                + '<span>Plan: <b>' + esc(cust.plan || '-') + '</b></span>'
                + '<span class="label ' + stCls + '">' + esc(stTxt) + '</span>'
                + (cust.expiration ? '<span>Expires: <b>' + esc(cust.expiration) + '</b></span>' : '')
                + '</div>'
                + '<a href="' + esc(cust.url) + '" target="_blank" class="cp-btn cp-btn-sm"><i class="fa fa-external-link"></i> Profile</a>';
            return;
        }
        customerBox.className = 'cp-customer-bar is-guest';
        customerBox.innerHTML = '<span><i class="fa fa-user-secret"></i> Guest / Unregistered visitor</span>'
            + '<div style="display:flex;gap:6px;align-items:center;">'
            + '<input type="text" id="cpchatManualLookup" class="form-control input-sm" style="width:180px;height:28px;" placeholder="Lookup username / phone">'
            + '<button type="button" id="cpchatManualLookupBtn" class="cp-btn cp-btn-sm">Find</button>'
            + '</div>';
        var btn = document.getElementById('cpchatManualLookupBtn');
        var inp = document.getElementById('cpchatManualLookup');
        if (btn && inp && urls.lookup) {
            btn.onclick = function () {
                var q = (inp.value || '').trim();
                if (q.length < 2) { return; }
                get(param(urls.lookup, 'q', q), function (res) {
                    if (res && res.success && res.results && res.results.length) {
                        renderCustomerBox(res.results[0]);
                    } else {
                        toast('No matching customer found', true);
                    }
                });
            };
        }
    }

    function appendMessages(messages) {
        for (var i = 0; i < (messages || []).length; i++) {
            var m = messages[i];
            var row = document.createElement('div');
            if (m.sender === 'system') {
                row.className = 'text-center';
                row.style.margin = '6px 0';
                row.innerHTML = '<small class="text-muted">' + esc(m.body) + '</small>';
            } else if (m.sender === 'note') {
                row.className = 'text-right';
                row.style.marginBottom = '8px';
                var nb = document.createElement('div');
                nb.className = 'cp-note-bubble';
                nb.innerHTML = '<small style="display:block;font-weight:700;margin-bottom:2px;"><i class="fa fa-sticky-note-o"></i> Internal Note</small>'
                    + esc(m.body)
                    + '<small style="display:block;margin-top:4px;opacity:.75;">' + (m.sender_name ? esc(m.sender_name) + ' · ' : '') + esc(m.time) + '</small>';
                row.appendChild(nb);
            } else {
                var isMe = m.sender === 'admin';
                row.className = isMe ? 'text-right' : '';
                row.style.marginBottom = '8px';
                var bubble = document.createElement('div');
                bubble.className = 'well well-sm' + (isMe ? ' cpchat-admin-bubble' : '');
                bubble.style.cssText = 'display:inline-block;max-width:75%;text-align:left;margin:0;word-break:break-word;'
                    + (isMe ? 'background-color:#337ab7;border-color:#2e6da4;color:#fff;' : '');
                var tsStyle = isMe ? 'display:block;margin-top:2px;color:rgba(255,255,255,.85);' : 'display:block;margin-top:2px;color:#777;';
                bubble.innerHTML = esc(m.body)
                    + '<small style="' + tsStyle + '">'
                    + (isMe && m.sender_name ? esc(m.sender_name) + ' · ' : '') + esc(m.time) + '</small>';
                row.appendChild(bubble);
            }
            threadEl.appendChild(row);
        }
        threadEl.scrollTop = threadEl.scrollHeight;
    }

    function pollThreadNow() {
        if (!activeId) { return; }
        clearTimeout(threadTimer);
        var wait = Math.max(3000, pollEvery / 3);
        if (document.hidden) { wait = pollEvery; }
        threadTimer = setTimeout(function () {
            get(param(param(urls.thread, 'id', activeId), 'since', lastId), function (res) {
                if (res && res.success) {
                    if ((res.messages || []).length) {
                        appendMessages(res.messages);
                    }
                    if (res.conversation) {
                        activeTags = res.conversation.tags || activeTags;
                        paintTags();
                    }
                    if (typingEl) {
                        typingEl.style.display = res.customer_typing ? 'block' : 'none';
                    }
                }
                if (res && res.last_id) {
                    lastId = res.last_id;
                }
                pollThreadNow();
            });
        }, wait);
    }

    function sendReply() {
        var text = (replyEl.value || '').replace(/^\s+|\s+$/g, '');
        if (!text || !activeId) { return; }
        sendBtn.disabled = true;
        replyEl.disabled = true;
        post(urls.send, { id: activeId, body: text, type: replyMode }, function (res) {
            sendBtn.disabled = false;
            replyEl.disabled = false;
            if (!res || !res.success) {
                toast(res && res.message ? res.message : 'Send failed', true);
                replyEl.focus();
                return;
            }
            replyEl.value = '';
            autoGrow();
            if (res.id > lastId) {
                appendMessages([{ id: res.id, sender: replyMode, body: text, time: (res.at || '').slice(11, 16), sender_name: '' }]);
                lastId = res.id;
            }
            if (res.assigned_to && assignEl) {
                assignEl.value = String(res.assigned_to);
            }
            loadListSoon();
            replyEl.focus();
        });
    }

    function loadListSoon() {
        setTimeout(function () { clearTimeout(listTimer); loadList(); }, 400);
    }

    function editTags() {
        if (!activeId) { return; }
        var list = activeTags || [];
        var boxes = tagOptions.map(function (t) {
            var on = list.indexOf(t) !== -1;
            return '<label style="display:inline-block;margin:0 12px 4px 0;font-weight:normal;"><input type="checkbox" value="' + esc(t) + '"' + (on ? ' checked' : '') + '> ' + esc(t) + '</label>';
        }).join('');
        if (!window.Swal) { return; }
        Swal.fire({
            title: 'Tags',
            html: '<div id="cpchatTagBox">' + boxes + '</div>'
                + '<div class="input-group" style="margin-top:10px;">'
                + '<input type="text" id="cpchatNewTag" class="form-control input-sm" maxlength="24" placeholder="new tag">'
                + '<span class="input-group-btn"><button type="button" class="btn btn-default btn-sm" id="cpchatAddTag">Add</button></span></div>',
            showCancelButton: true,
            confirmButtonText: 'Save',
            didOpen: function () {
                var add = document.getElementById('cpchatAddTag');
                var box = document.getElementById('cpchatNewTag');
                add.onclick = function () {
                    var value = (box.value || '').replace(/^\s+|\s+$/g, '').toLowerCase();
                    if (!value) { return; }
                    var label = document.createElement('label');
                    label.style.cssText = 'display:inline-block;margin:0 12px 4px 0;font-weight:normal;';
                    label.innerHTML = '<input type="checkbox" value="' + esc(value) + '" checked> ' + esc(value);
                    document.getElementById('cpchatTagBox').appendChild(label);
                    box.value = '';
                };
                box.onkeydown = function (e) {
                    if (e.key === 'Enter') { e.preventDefault(); add.click(); }
                };
            },
            preConfirm: function () {
                var boxes2 = document.getElementById('cpchatTagBox').querySelectorAll('input[type=checkbox]');
                var out = [];
                for (var i = 0; i < boxes2.length; i++) {
                    if (boxes2[i].checked) { out.push(boxes2[i].value); }
                }
                return out;
            }
        }).then(function (res) {
            if (!res.isConfirmed) { return; }
            post(urls.tags, { id: activeId, tags: res.value.join(',') }, function (r) {
                if (r && r.success) {
                    activeTags = r.tags || [];
                    paintTags();
                    loadListSoon();
                    toast('Tags saved');
                } else {
                    toast('Cannot save tags', true);
                }
            });
        });
    }

    function closeWithReason() {
        if (!activeId || !window.Swal) { return; }
        var opts = closeReasons.map(function (r) {
            return '<option value="' + esc(r) + '">' + esc(r) + '</option>';
        }).join('');
        var cannedOpts = '<option value="">' + esc('Insert canned reply…') + '</option>';
        (cfg.canned || []).forEach(function (k) {
            cannedOpts += '<option value="' + esc(k.body) + '">' + esc(k.title) + '</option>';
        });
        Swal.fire({
            title: 'Close chat',
            html: '<div class="form-group" style="text-align:left;">'
                + '<label>Why is this chat closing?</label>'
                + '<select id="cpchatReason" class="form-control">' + opts + '</select></div>'
                + '<div class="form-group" style="text-align:left;">'
                + '<label>Send a final message to the customer (optional)</label>'
                + '<select id="cpchatCloseCanned" class="form-control input-sm" style="margin-bottom:6px;">' + cannedOpts + '</select>'
                + '<textarea id="cpchatNote" class="form-control" rows="3" maxlength="500"></textarea></div>',
            showCancelButton: true,
            confirmButtonText: 'Close',
            focusConfirm: false,
            didOpen: function () {
                var sel = document.getElementById('cpchatCloseCanned');
                var box = document.getElementById('cpchatNote');
                if (sel && box) {
                    sel.onchange = function () {
                        if (sel.value) { box.value = sel.value; }
                        sel.value = '';
                        box.focus();
                    };
                }
            },
            preConfirm: function () {
                return {
                    reason: document.getElementById('cpchatReason').value,
                    note: document.getElementById('cpchatNote').value
                };
            }
        }).then(function (res) {
            if (!res.isConfirmed) { return; }
            var reason = res.value.reason;
            var note = res.value.note;
            post(urls.close, { id: activeId, reason: reason, note: note }, function (r) {
                if (r && r.success) {
                    activeStatus = 'closed';
                    statusEl.className = 'label label-default';
                    statusEl.innerHTML = esc('closed · ' + reason);
                    toggleBtn.innerHTML = 'Reopen';
                    if (note && note.replace(/^\s+|\s+$/g, '')) {
                        appendMessages([{ sender: 'admin', body: note, time: '', sender_name: '' }]);
                    }
                    loadListSoon();
                    toast('Chat closed');
                } else {
                    toast('Cannot close chat', true);
                }
            });
        });
    }

    function autoGrow() {
        if (!replyEl) { return; }
        replyEl.style.height = 'auto';
        var cap = 160;
        var h = Math.min(replyEl.scrollHeight, cap);
        replyEl.style.height = (h || 34) + 'px';
        replyEl.style.overflowY = (replyEl.scrollHeight > cap) ? 'auto' : 'hidden';
    }
    if (replyEl) {
        replyEl.onkeydown = function (ev) {
            if (ev.key === 'Enter' && !ev.shiftKey) {
                ev.preventDefault();
                sendReply();
            }
        };
        replyEl.oninput = autoGrow;
    }
    if (sendBtn) {
        sendBtn.onclick = sendReply;
    }
    if (toggleBtn) {
        toggleBtn.onclick = function () {
            if (!activeId) { return; }
            if (activeStatus === 'open') {
                closeWithReason();
                return;
            }
            post(urls.status, { id: activeId, status: 'open' }, function (res) {
                if (res && res.success) {
                    activeStatus = res.status;
                    statusEl.className = 'label label-success';
                    statusEl.innerHTML = esc(res.status);
                    toggleBtn.innerHTML = 'Close';
                    loadListSoon();
                }
            });
        };
    }
    if (assignEl) {
        assignEl.onchange = function () {
            if (!activeId) { return; }
            post(urls.assign, { id: activeId, assigned_to: assignEl.value }, function (res) {
                if (res && res.success) {
                    toast(res.assigned_name ? ('Assigned to ' + res.assigned_name) : 'Unassigned');
                    loadListSoon();
                } else {
                    toast('Cannot assign', true);
                }
            });
        };
    }
    if (tagBtn) {
        tagBtn.onclick = editTags;
    }
    function expandVars(text) {
        var c = activeConv || {};
        var cu = activeCustomer || {};
        return String(text || '')
            .replace(/\{\{name\}\}/g, c.name || cu.fullname || 'Customer')
            .replace(/\{\{phone\}\}/g, c.phone || cu.phonenumber || '')
            .replace(/\{\{username\}\}/g, c.username || cu.username || '')
            .replace(/\{\{plan\}\}/g, cu.plan || '')
            .replace(/\{\{expiry\}\}/g, cu.expiration || '');
    }

    if (modeReplyBtn && modeNoteBtn) {
        modeReplyBtn.onclick = function () {
            replyMode = 'admin';
            modeReplyBtn.className = 'cp-mode-btn active';
            modeNoteBtn.className = 'cp-mode-btn note';
            sendBtn.innerHTML = '<i class="fa fa-paper-plane"></i> Reply';
            replyEl.placeholder = 'Type your reply, Enter to send (/ for canned)';
        };
        modeNoteBtn.onclick = function () {
            replyMode = 'note';
            modeReplyBtn.className = 'cp-mode-btn';
            modeNoteBtn.className = 'cp-mode-btn note active';
            sendBtn.innerHTML = '<i class="fa fa-sticky-note-o"></i> Save Note';
            replyEl.placeholder = 'Write an internal team note (hidden from customer)...';
        };
    }

    if (cannedEl) {
        cannedEl.onchange = function () {
            if (!cannedEl.value) { return; }
            replyEl.value = expandVars(cannedEl.value);
            cannedEl.value = '';
            if (typeof autoGrow === 'function') { autoGrow(); }
            replyEl.focus();
        };
    }

    if (replyEl && slashMenu) {
        var cannedList = cfg.canned || [];
        replyEl.addEventListener('input', function () {
            if (activeId && replyMode === 'admin' && urls.typing) {
                var now = Date.now();
                if (now - lastAdminTyping > 3000) {
                    lastAdminTyping = now;
                    post(urls.typing, { id: activeId }, function () {});
                }
            }
            var val = replyEl.value || '';
            if (val.charAt(0) === '/' && cannedList.length) {
                var q = val.slice(1).toLowerCase();
                var hits = cannedList.filter(function (item) {
                    return !q || (item.title || '').toLowerCase().indexOf(q) !== -1 || (item.body || '').toLowerCase().indexOf(q) !== -1;
                }).slice(0, 6);
                if (hits.length) {
                    slashMenu.innerHTML = hits.map(function (h, idx) {
                        return '<div class="cp-slash-item" data-idx="' + idx + '"><b>' + esc(h.title) + '</b><small>' + esc(h.body) + '</small></div>';
                    }).join('');
                    slashMenu.style.display = 'block';
                    var items = slashMenu.querySelectorAll('.cp-slash-item');
                    for (var i = 0; i < items.length; i++) {
                        items[i].onclick = function () {
                            var h = hits[parseInt(this.getAttribute('data-idx'), 10)];
                            if (h) {
                                replyEl.value = expandVars(h.body);
                                slashMenu.style.display = 'none';
                                if (typeof autoGrow === 'function') { autoGrow(); }
                                replyEl.focus();
                            }
                        };
                    }
                    return;
                }
            }
            slashMenu.style.display = 'none';
        });
    }

    function bindMenuAction(id, fn) {
        var el = document.getElementById(id);
        if (el) {
            el.onclick = function (ev) {
                ev.preventDefault();
                fn();
            };
        }
    }
    bindMenuAction('cpchatSpamBtn', function () {
        if (!activeId) { return; }
        post(urls.spam, { id: activeId, spam: 1 }, function (res) {
            if (res && res.success) {
                activeStatus = 'closed';
                toast('Marked as spam');
                loadListSoon();
                statusEl.className = 'label label-danger';
                statusEl.innerHTML = 'closed · Spam';
            }
        });
    });
    bindMenuAction('cpchatBlockBtn', function () {
        if (!activeId) { return; }
        post(urls.block, { id: activeId, hours: 24 }, function (res) {
            if (res && res.success) {
                toast('Blocked: ' + (res.blocked || []).join(', '));
            }
        });
    });
    bindMenuAction('cpchatChatCsv', function () { if (activeId) { window.location = param(urls.csv, 'id', activeId); } });
    bindMenuAction('cpchatChatPdf', function () { if (activeId) { window.location = param(urls.pdf, 'id', activeId); } });

    var expCsv = document.getElementById('cpchatExportCsv');
    if (expCsv) {
        expCsv.onclick = function () { window.location = param(filterUrl(urls.csv), 'scope', 'list'); };
    }
    var expPdf = document.getElementById('cpchatExportPdf');
    if (expPdf) {
        expPdf.onclick = function () { window.location = param(filterUrl(urls.pdf), 'scope', 'list'); };
    }

    [searchEl, statusFilter, assignedFilter, routerFilter, tagFilter, spamFilter].forEach(function (node) {
        if (!node) { return; }
        node.onchange = function () { clearTimeout(listTimer); loadList(); };
    });
    if (searchEl) {
        searchEl.onkeyup = function () {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(loadList, 500);
        };
    }

    bindList();
    if (activeId) {
        showThread();
        setCompose(true);
        pollThreadNow();
    } else {
        showList();
        setCompose(false);
    }
    scheduleList();
})();
</script>
{/literal}

{include file="sections/footer.tpl"}
