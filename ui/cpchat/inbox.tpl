{include file="sections/header.tpl"}

<div class="row">
    <div class="col-md-12">
        <div class="panel panel-primary panel-hovered panel-stacked mb30">
            <div class="panel-heading">
                <div class="btn-group pull-right">
                    <a href="{$_url}plugin/captivePortalChat" class="btn btn-default btn-xs"><i class="fa fa-dashboard"></i> {Lang::T('Dashboard')}</a>
                    <a href="{$_url}plugin/captivePortalChatSettings" class="btn btn-default btn-xs"><i class="fa fa-cog"></i> {Lang::T('Settings')}</a>
                    <a href="{$_url}plugin/captivePortalChatSettings#tabCanned" class="btn btn-default btn-xs"><i class="fa fa-reply"></i> {Lang::T('Canned replies')}</a>
                </div>
                <div style="clear:both;margin-top:8px;">
                    {if $open_now}
                        <span class="label label-success"><i class="fa fa-circle"></i> {Lang::T('Online')}</span>
                    {else}
                        <span class="label label-warning" title="{$hours_label|escape:'html'}"><i class="fa fa-moon-o"></i> {Lang::T('Offline')}</span>
                    {/if}
                    <span class="label label-info" title="{Lang::T('Open chats')}">{Lang::T('Open')}: {$stats.open|default:0}</span>
                    <span class="label label-warning" title="{Lang::T('Waiting for a reply')}">{Lang::T('Waiting')}: {$stats.waiting|default:0}</span>
                    <span class="label label-danger" title="{Lang::T('Unread messages')}">{Lang::T('Unread')}: {$stats.unread|default:0}</span>
                </div>
            </div>
            <div class="panel-body">

                {if $install_error neq ''}
                    <div class="alert alert-danger">
                        {Lang::T('Chat tables could not be created')}: {$install_error|escape:'html'}
                    </div>
                {/if}
                {if $navbar_state.status neq 'installed'}
                    <div class="alert alert-warning">
                        {Lang::T('The navbar notification bell is not installed yet.')}
                        <a href="{$_url}plugin/captivePortalChatSettings" class="btn btn-primary btn-xs" style="margin-left:10px;">{Lang::T('Install it')}</a>
                    </div>
                {/if}
                {if !$open_now && $s.hours_enabled}
                    <div class="alert alert-info">
                        <i class="fa fa-clock-o"></i> {Lang::T('Outside support hours')} &mdash; {$hours_label|escape:'html'}.
                        {Lang::T('Customers see the away message until the team is back.')}
                    </div>
                {/if}

                <div id="cpchatListView">
                    <div class="panel panel-default">
                        <div class="panel-heading">
                            <input type="text" id="cpchatSearch" class="form-control input-sm"
                                value="{$filters.q|escape:'html'}" placeholder="{Lang::T('Search name, phone, mac, ip, tag or message')}">
                        </div>
                        <div class="panel-body">
                            <div class="row">
                                <div class="col-xs-6 col-sm-3" style="margin-bottom:6px;">
                                    <select id="cpchatStatus" class="form-control input-sm">
                                        <option value="">{Lang::T('Any status')}</option>
                                        <option value="open" {if $filters.status eq 'open'}selected{/if}>{Lang::T('Open only')}</option>
                                        <option value="closed" {if $filters.status eq 'closed'}selected{/if}>{Lang::T('Closed only')}</option>
                                    </select>
                                </div>
                                <div class="col-xs-6 col-sm-3" style="margin-bottom:6px;">
                                    <select id="cpchatAssigned" class="form-control input-sm">
                                        <option value="">{Lang::T('Everyone')}</option>
                                        <option value="unassigned" {if $filters.assigned eq 'unassigned'}selected{/if}>{Lang::T('Unassigned')}</option>
                                        <option value="me" {if $filters.assigned eq 'me'}selected{/if}>{Lang::T('Assigned to me')}</option>
                                        {foreach $agents as $a}
                                            <option value="{$a.id}" {if $filters.assigned eq $a.id}selected{/if}>{$a.name|escape:'html'}</option>
                                        {/foreach}
                                    </select>
                                </div>
                                <div class="col-xs-6 col-sm-3" style="margin-bottom:6px;">
                                    <select id="cpchatRouter" class="form-control input-sm">
                                        <option value="">{Lang::T('All routers')}</option>
                                        {foreach $routers as $r}
                                            <option value="{$r|escape:'html'}" {if $filters.router eq $r}selected{/if}>{$r|escape:'html'}</option>
                                        {/foreach}
                                    </select>
                                </div>
                                <div class="col-xs-6 col-sm-3" style="margin-bottom:6px;">
                                    <select id="cpchatTag" class="form-control input-sm">
                                        <option value="">{Lang::T('All tags')}</option>
                                        {foreach $tagOptions as $t}
                                            <option value="{$t|escape:'html'}" {if $filters.tag eq $t}selected{/if}>{$t|escape:'html'}</option>
                                        {/foreach}
                                    </select>
                                </div>
                            </div>
                            <div style="margin-top:8px;">
                                <label style="font-weight:normal;margin:0;">
                                    <input type="checkbox" id="cpchatSpam" value="1"> {Lang::T('Spam')}
                                </label>
                                <span class="pull-right">
                                    <button type="button" class="btn btn-default btn-xs" id="cpchatExportCsv" title="{Lang::T('Export this list as CSV')}">
                                        <i class="fa fa-file-text-o"></i> CSV
                                    </button>
                                    <button type="button" class="btn btn-default btn-xs" id="cpchatExportPdf" title="{Lang::T('Export this list as PDF')}">
                                        <i class="fa fa-file-pdf-o"></i> PDF
                                    </button>
                                </span>
                            </div>
                        </div>
                        <div id="cpchatList" class="list-group" style="margin:0;border:0;border-radius:0;">
                            {foreach $conversations as $c}
                                <a href="#" class="list-group-item cpchat-conv{if $c.id eq $active_id} list-group-item-info{/if}{if $c.is_spam} list-group-item-danger{/if}" data-id="{$c.id}">
                                    <div class="pull-right"><small class="text-muted">{$c.last_ago|escape:'html'}</small></div>
                                    <strong>{$c.name|escape:'html'}</strong> <small class="text-muted">{$c.phone|escape:'html'}</small>
                                    <div style="clear:both;">
                                        {if $c.username neq ''}<small class="text-muted"><i class="fa fa-user"></i> {$c.username|escape:'html'}</small> &nbsp;{/if}
                                        {if $c.mac neq ''}<small class="text-muted"><i class="fa fa-wifi"></i> {$c.mac|escape:'html'}</small>{/if}
                                        {if $c.router neq ''} &nbsp;<small class="text-muted"><i class="fa fa-server"></i> {$c.router|escape:'html'}</small>{/if}
                                    </div>
                                    {if $c.tags|@count > 0 || $c.assigned_name neq '' || $c.is_spam || $c.close_reason neq ''}
                                        <div style="margin-top:3px;">
                                            {foreach $c.tags as $t}<span class="label label-default">{$t|escape:'html'}</span> {/foreach}
                                            {if $c.assigned_name neq ''}<span class="label label-info"><i class="fa fa-headphones"></i> {$c.assigned_name|escape:'html'}</span> {/if}
                                            {if $c.is_spam}<span class="label label-danger">{Lang::T('Spam')}</span> {/if}
                                            {if $c.close_reason neq ''}<span class="label label-warning">{$c.close_reason|escape:'html'}</span>{/if}
                                        </div>
                                    {/if}
                                    <div style="margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
                                        {if $c.unread_admin > 0}<span class="badge bg-red">{$c.unread_admin}</span> {/if}
                                        <small>{$c.last_body|escape:'html'|truncate:60}</small>
                                    </div>
                                </a>
                            {/foreach}
                            {if $conversations|@count eq 0}
                                <div class="list-group-item text-center text-muted">{Lang::T('No chats match these filters.')}</div>
                            {/if}
                        </div>
                    </div>
                </div>
                <div id="cpchatThreadView" style="display:none;">
                    <div class="panel panel-default">
                        <div class="panel-heading">
                            <div class="pull-right" style="margin-left:8px;">
                                <select id="cpchatAssign" class="form-control input-sm" style="width:auto;max-width:160px;display:inline-block;vertical-align:middle;" disabled>
                                    <option value="0">{Lang::T('Unassigned')}</option>
                                    <option value="me">{Lang::T('Assign to me')}</option>
                                    {foreach $agents as $a}
                                        <option value="{$a.id}">{$a.name|escape:'html'}</option>
                                    {/foreach}
                                </select>
                                <button type="button" class="btn btn-default btn-xs" id="cpchatTagBtn" disabled title="{Lang::T('Edit tags')}" style="vertical-align:middle;">
                                    <i class="fa fa-tag"></i>
                                </button>
                                <div class="btn-group" style="display:inline-block;vertical-align:middle;">
                                    <button type="button" class="btn btn-default btn-xs dropdown-toggle" id="cpchatMoreBtn" disabled data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                                        <i class="fa fa-ellipsis-h"></i> <span class="caret"></span>
                                    </button>
                                    <ul class="dropdown-menu dropdown-menu-right">
                                        <li><a href="#" id="cpchatSpamBtn"><i class="fa fa-ban"></i> {Lang::T('Mark as spam')}</a></li>
                                        <li><a href="#" id="cpchatBlockBtn"><i class="fa fa-user-times"></i> {Lang::T('Block this visitor')}</a></li>
                                        <li role="separator" class="divider"></li>
                                        <li><a href="#" id="cpchatChatCsv"><i class="fa fa-file-text-o"></i> {Lang::T('Transcript CSV')}</a></li>
                                        <li><a href="#" id="cpchatChatPdf"><i class="fa fa-file-pdf-o"></i> {Lang::T('Transcript PDF')}</a></li>
                                    </ul>
                                </div>
                                <button type="button" class="btn btn-primary btn-xs" id="cpchatToggleStatus" style="vertical-align:middle;" {if !$active}disabled{/if}>
                                    {if $active}{if $active.status eq 'open'}{Lang::T('Close')}{else}{Lang::T('Reopen')}{/if}{else}{Lang::T('Close')}{/if}
                                </button>
                            </div>
                            <button type="button" class="btn btn-default btn-xs" id="cpchatBackBtn" style="vertical-align:middle;"><i class="fa fa-arrow-left"></i> {Lang::T('Back')}</button>
                            <span id="cpchatThreadTitle" style="margin-left:8px;font-size:14px;vertical-align:middle;">
                                {if $active}
                                    {$active.name|escape:'html'} <small>{$active.phone|escape:'html'}</small>
                                {else}
                                    {Lang::T('Select a chat')}
                                {/if}
                            </span>
                            <span class="label label-default" id="cpchatThreadStatus" style="margin-left:6px;vertical-align:middle;">{if $active}{$active.status}{else}&ndash;{/if}</span>
                        </div>

                        <div class="panel-footer" id="cpchatMetaBar"{if !$active} style="display:none;padding-top:6px;padding-bottom:6px;"{else} style="padding-top:6px;padding-bottom:6px;"{/if}>
                            {if $active}
                                <div class="row" style="margin:0;">
                                    <div class="col-xs-6 col-sm-4 col-md-2"><small class="text-muted"><i class="fa fa-mobile"></i> {Lang::T('Phone')}:</small> <code>{$active.phone|escape:'html'}</code></div>
                                    <div class="col-xs-6 col-sm-4 col-md-2"><small class="text-muted"><i class="fa fa-user"></i> {Lang::T('Name')}:</small> <code>{$active.name|escape:'html'}</code></div>
                                    {if $active.mac neq ''}
                                        <div class="col-xs-6 col-sm-4 col-md-2"><small class="text-muted"><i class="fa fa-wifi"></i> MAC:</small> <code>{$active.mac|escape:'html'}</code></div>
                                    {/if}
                                    {if $active.ip neq ''}
                                        <div class="col-xs-6 col-sm-4 col-md-2"><small class="text-muted"><i class="fa fa-globe"></i> IP:</small> <code>{$active.ip|escape:'html'}</code></div>
                                    {/if}
                                    {if $active.username neq ''}
                                        <div class="col-xs-6 col-sm-4 col-md-2"><small class="text-muted"><i class="fa fa-sign-in"></i> {Lang::T('Username')}:</small> <code>{$active.username|escape:'html'}</code></div>
                                    {/if}
                                    {if $active.router neq ''}
                                        <div class="col-xs-6 col-sm-4 col-md-2"><small class="text-muted"><i class="fa fa-server"></i> {Lang::T('Router')}:</small> <code>{$active.router|escape:'html'}</code></div>
                                    {/if}
                                    {if $active.page neq ''}
                                        <div class="col-xs-6 col-sm-4 col-md-2"><small class="text-muted"><i class="fa fa-file-o"></i> {Lang::T('Page')}:</small> <code>{$active.page|escape:'html'}</code></div>
                                    {/if}
                                    <div class="col-xs-6 col-sm-4 col-md-2"><small class="text-muted"><i class="fa fa-clock-o"></i> {Lang::T('Created')}:</small> <code>{Lang::dateTimeFormat($active.created_at)}</code></div>
                                </div>
                            {/if}
                        </div>

                        <div id="cpchatThread" class="panel-body" style="background:var(--cpchat-bg-thread,#f4f6f9);min-height:200px;">
                            {if $active}
                                {foreach $thread as $m}
                                    {if $m.sender eq 'system'}
                                        <div class="text-center" style="margin:6px 0;">
                                            <small class="text-muted">{$m.body|escape:'html'|nl2br}</small>
                                        </div>
                                    {else}
                                        <div class="{if $m.sender eq 'admin'}text-right{/if}" style="margin-bottom:8px;">
                                            <div class="well well-sm{if $m.sender eq 'admin'} cpchat-admin-bubble{/if}" style="display:inline-block;max-width:75%;text-align:left;margin:0;word-break:break-word;{if $m.sender eq 'admin'}background-color:#337ab7;border-color:#2e6da4;color:#fff;{/if}">
                                                {$m.body|escape:'html'|nl2br}
                                                <small style="display:block;margin-top:2px;{if $m.sender eq 'admin'}color:rgba(255,255,255,.85);{else}color:#777;{/if}">{if $m.sender eq 'admin' && $m.sender_name neq ''}{$m.sender_name|escape:'html'} · {/if}{$m.time}</small>
                                            </div>
                                        </div>
                                    {/if}
                                {/foreach}
                            {else}
                                <div class="text-muted text-center" style="padding:30px 10px;">
                                    <i class="fa fa-comments-o" style="font-size:34px;display:block;margin-bottom:8px;"></i>
                                    {Lang::T('Select a chat from the list.')}
                                </div>
                            {/if}
                        </div>

                        <div class="panel-footer">
                            <div style="margin-bottom:8px;">
                                <select id="cpchatCanned" class="form-control input-sm" style="width:220px;max-width:100%;display:inline-block;" disabled>
                                    <option value="">{Lang::T('Canned replies')}…</option>
                                    {foreach $canned as $k}
                                        <option value="{$k.body|escape:'html'}">{$k.title|escape:'html'|truncate:48}</option>
                                    {/foreach}
                                </select>
                                <span id="cpchatTagList" class="pull-right">
                                    {if $active}{foreach $active.tags as $t}<span class="label label-default">{$t|escape:'html'}</span> {/foreach}{/if}
                                </span>
                            </div>
                            <textarea id="cpchatReply" class="form-control" rows="2"
                                placeholder="{Lang::T('Type your reply, Enter to send')}"{if !$active} disabled{/if}></textarea>
                            <button type="button" class="btn btn-primary btn-block" id="cpchatSendReply" style="margin-top:8px;"{if !$active} disabled{/if}>
                                <i class="fa fa-paper-plane"></i> {Lang::T('Reply')}
                            </button>
                        </div>
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
        metaEl.innerHTML = '<div class="row" style="margin:0;">' + cells.join('') + '</div>';
        metaEl.style.display = '';
    }

    function metaCell(icon, label, value) {
        return '<div class="col-xs-6 col-sm-4 col-md-2">'
            + '<small class="text-muted"><i class="fa ' + icon + '"></i> ' + esc(label) + ':</small> <code>' + esc(value) + '</code></div>';
    }

    function appendMessages(messages) {
        for (var i = 0; i < (messages || []).length; i++) {
            var m = messages[i];
            var row = document.createElement('div');
            if (m.sender === 'system') {
                row.className = 'text-center';
                row.style.margin = '6px 0';
                row.innerHTML = '<small class="text-muted">' + esc(m.body) + '</small>';
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
        post(urls.send, { id: activeId, body: text }, function (res) {
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
                appendMessages([{ id: res.id, sender: 'admin', body: text, time: (res.at || '').slice(11, 16), sender_name: '' }]);
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
    if (cannedEl) {
        cannedEl.onchange = function () {
            if (!cannedEl.value) { return; }
            replyEl.value = cannedEl.value;
            cannedEl.value = '';
            if (typeof autoGrow === 'function') { autoGrow(); }
            replyEl.focus();
        };
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
