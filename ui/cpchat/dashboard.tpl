{include file="sections/header.tpl"}

<div class="cp-page">
    <div class="cp-head">
        <div class="cp-head-title">
            <h2><i class="fa fa-comments" style="color:#2563eb;margin-right:6px;"></i> {Lang::T('Captive Portal Chat')}</h2>
            {if $open_now}
                <span class="cp-pill cp-pill-ok"><i class="fa fa-circle" style="font-size:8px;"></i> {Lang::T('Online')}</span>
            {else}
                <span class="cp-pill cp-pill-warn" title="{$hours_label|escape:'html'}"><i class="fa fa-moon-o"></i> {Lang::T('Offline')}</span>
            {/if}
        </div>
        <div class="cp-head-actions">
            <a href="{$_url}plugin/captivePortalChatInbox" class="cp-btn cp-btn-primary"><i class="fa fa-inbox"></i> {Lang::T('Open Inbox')}</a>
            {if $can_manage}<a href="{$_url}plugin/captivePortalChatSettings" class="cp-btn"><i class="fa fa-cog"></i> {Lang::T('Settings')}</a>{/if}
        </div>
    </div>

    {if $install_error neq ''}
        <div class="cp-banner cp-banner-bad">
            <span>{Lang::T('Chat tables could not be created')}: {$install_error|escape:'html'}</span>
        </div>
    {/if}
    {if $can_manage && !$s.enabled}
        <div class="cp-banner cp-banner-info">
            <span><i class="fa fa-info-circle"></i> {Lang::T('Chat is currently disabled. Customers cannot start new chats.')}</span>
            <a href="{$_url}plugin/captivePortalChatSettings" class="cp-btn cp-btn-sm">{Lang::T('Enable it')}</a>
        </div>
    {/if}

    <div class="cp-kpis">
        <div class="cp-kpi">
            <div><div class="cp-kpi-val">{$stats.open|default:0}</div><div class="cp-kpi-lbl">{Lang::T('Open chats')}</div></div>
            <div class="cp-kpi-ico cp-ico-blue"><i class="fa fa-comments-o"></i></div>
        </div>
        <div class="cp-kpi">
            <div><div class="cp-kpi-val">{$stats.waiting|default:0}</div><div class="cp-kpi-lbl">{Lang::T('Waiting for a reply')}</div></div>
            <div class="cp-kpi-ico cp-ico-amber"><i class="fa fa-clock-o"></i></div>
        </div>
        <div class="cp-kpi">
            <div><div class="cp-kpi-val">{$stats.unread|default:0}</div><div class="cp-kpi-lbl">{Lang::T('Unread messages')}</div></div>
            <div class="cp-kpi-ico cp-ico-red"><i class="fa fa-bell-o"></i></div>
        </div>
        <div class="cp-kpi">
            <div><div class="cp-kpi-val">{$stats.today|default:0}</div><div class="cp-kpi-lbl">{Lang::T('Chats started today')}</div></div>
            <div class="cp-kpi-ico cp-ico-green"><i class="fa fa-plus"></i></div>
        </div>
        <div class="cp-kpi">
            <div><div class="cp-kpi-val">{$stats.closed|default:0}</div><div class="cp-kpi-lbl">{Lang::T('Closed chats')}</div></div>
            <div class="cp-kpi-ico cp-ico-teal"><i class="fa fa-check"></i></div>
        </div>
        <div class="cp-kpi">
            <div><div class="cp-kpi-val">{if $stats.avg_first_reply !== null}{$stats.avg_first_reply} {Lang::T('min')}{else}&ndash;{/if}</div><div class="cp-kpi-lbl">{Lang::T('Average first reply')}</div></div>
            <div class="cp-kpi-ico cp-ico-purple"><i class="fa fa-bolt"></i></div>
        </div>
        <div class="cp-kpi">
            <div><div class="cp-kpi-val">{$spam.hits_24h|default:0}</div><div class="cp-kpi-lbl">{Lang::T('Blocked attempts (24h)')}</div></div>
            <div class="cp-kpi-ico cp-ico-red"><i class="fa fa-shield"></i></div>
        </div>
        <div class="cp-kpi">
            <div><div class="cp-kpi-val">{$stats.messages|default:0}</div><div class="cp-kpi-lbl">{Lang::T('Messages in total')}</div></div>
            <div class="cp-kpi-ico cp-ico-slate"><i class="fa fa-comments"></i></div>
        </div>
    </div>

    <div class="cp-grid-2">
        <div class="cp-card">
            <div class="cp-card-head"><span><i class="fa fa-bar-chart"></i> {Lang::T('Last 14 days')}</span></div>
            <div class="cp-card-body">
                <div id="cpchatChart"></div>
                {if $chart_empty}
                    <p class="cp-help" style="text-align:center;margin-top:10px;">{Lang::T('No chats or messages in the last 14 days')}</p>
                {/if}
            </div>
        </div>

        <div class="cp-card">
            <div class="cp-card-head"><span><i class="fa fa-user"></i> {Lang::T('Agent workload')}</span></div>
            <div class="cp-card-body-flush cp-table-wrap">
                <table class="cp-table">
                    <thead>
                        <tr>
                            <th>{Lang::T('Agent')}</th>
                            <th class="cp-tr">{Lang::T('Chats')}</th>
                            <th class="cp-tr">{Lang::T('Open')}</th>
                            <th class="cp-tr">{Lang::T('Unread')}</th>
                        </tr>
                    </thead>
                    <tbody>
                        {foreach $workload as $w}
                            <tr>
                                <td><a href="{$_url}plugin/captivePortalChatInbox&assigned={$w.id}"><b>{$w.name|escape:'html'}</b></a> <small style="color:var(--cpchat-text-muted);">{$w.type|escape:'html'}</small></td>
                                <td class="cp-tr">{$w.total}</td>
                                <td class="cp-tr">{$w.open_chats}</td>
                                <td class="cp-tr">{$w.unread}</td>
                            </tr>
                        {/foreach}
                        {if $workload|@count eq 0}
                            <tr><td colspan="4" style="text-align:center;color:var(--cpchat-text-muted);">{Lang::T('No active agents')}</td></tr>
                        {/if}
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="cp-card">
        <div class="cp-card-head">
            <span><i class="fa fa-inbox"></i> {Lang::T('Latest chats')}</span>
            <a class="cp-btn cp-btn-sm" href="{$_url}plugin/captivePortalChatInbox">{Lang::T('All chats')}</a>
        </div>
        <div class="cp-card-body-flush cp-table-wrap">
            <table class="cp-table">
                <thead>
                    <tr>
                        <th>{Lang::T('Customer')}</th>
                        <th>{Lang::T('Last message')}</th>
                        <th>{Lang::T('Tags')}</th>
                        <th>{Lang::T('Agent')}</th>
                        <th class="cp-tr">{Lang::T('Time')}</th>
                        <th class="cp-tr">{Lang::T('Actions')}</th>
                    </tr>
                </thead>
                <tbody>
                    {foreach $latest as $c}
                        <tr class="cpchat-row-link" data-url="{$_url}plugin/captivePortalChatInbox&id={$c.id}">
                            <td>
                                <a href="{$_url}plugin/captivePortalChatInbox&id={$c.id}"><b>{$c.name|escape:'html'}</b></a>
                                <small style="color:var(--cpchat-text-muted);">{$c.phone|escape:'html'}</small>
                                {if $c.status eq 'open'}<span class="label label-success">open</span>{else}<span class="label label-default">closed</span>{/if}
                                {if $c.unread_admin > 0}<span class="badge bg-red">{$c.unread_admin}</span>{/if}
                            </td>
                            <td>{$c.last_body|escape:'html'|truncate:70}</td>
                            <td>{foreach $c.tags as $t}<span class="label label-default" style="margin-right:2px;">{$t|escape:'html'}</span>{/foreach}</td>
                            <td><small>{$c.assigned_name|escape:'html'|default:'&ndash;'}</small></td>
                            <td class="cp-tr"><small>{$c.last_dt}</small></td>
                            <td class="cp-tr" style="white-space:nowrap;">
                                <a href="{$_url}plugin/captivePortalChatInbox&id={$c.id}" class="cp-btn cp-btn-primary cp-btn-sm">{Lang::T('View')}</a>
                                <button type="button" class="cp-btn cp-btn-danger cp-btn-sm cpchat-del" data-id="{$c.id}">{Lang::T('Delete')}</button>
                            </td>
                        </tr>
                    {/foreach}
                    {if $latest|@count eq 0}
                        <tr><td colspan="6" style="text-align:center;color:var(--cpchat-text-muted);padding:24px;">{Lang::T('No chats yet. Add the widget snippet to your hotspot login page.')}</td></tr>
                    {/if}
                </tbody>
            </table>
        </div>
    </div>
</div>

{if !$chart_empty}
<script>
(function () {
    var el = document.getElementById('cpchatChart');
    if (!el || !window.ApexCharts) {
        return;
    }
    var dark = document.body.className.indexOf('dark-mode') !== -1;
    var data = {$chart_json};
    var grid = dark ? '#3d4b5c' : '#e5e5e5';
    var fore = dark ? '#c9d1d9' : '#555';
    new ApexCharts(el, {
        chart: {
            type: 'area',
            height: 300,
            background: 'transparent',
            foreColor: fore,
            fontFamily: 'inherit',
            toolbar: { show: false },
            zoom: { enabled: false }
        },
        series: [
            { name: '{Lang::T('Chats')}', data: data.map(function (d) { return d.chats; }) },
            { name: '{Lang::T('Messages')}', data: data.map(function (d) { return d.messages; }) },
            { name: '{Lang::T('Closed')}', data: data.map(function (d) { return d.closed; }) },
            { name: '{Lang::T('Blocked')}', data: data.map(function (d) { return d.blocked; }) }
        ],
        stroke: {
            curve: 'smooth',
            width: 3
        },
        fill: {
            type: 'gradient',
            gradient: {
                shadeIntensity: 1,
                opacityFrom: .35,
                opacityTo: .03,
                stops: [0, 90, 100]
            }
        },
        markers: {
            size: 0,
            hover: { size: 6 }
        },
        xaxis: {
            categories: data.map(function (d) { return d.label; }),
            tickAmount: 7,
            axisBorder: { show: true, color: grid },
            axisTicks: { show: false }
        },
        yaxis: {
            min: 0,
            tickAmount: 4,
            forceNiceScale: true
        },
        grid: {
            borderColor: grid,
            strokeDashArray: 3,
            padding: { left: 8, right: 8 }
        },
        colors: ['#3c8dbc', '#00c0ef', '#45b000', '#dd4b39'],
        legend: {
            position: 'top',
            horizontalAlign: 'right',
            labels: { colors: fore }
        },
        dataLabels: { enabled: false },
        tooltip: {
            shared: true,
            theme: dark ? 'dark' : 'light',
            x: { show: true }
        }
    }).render();
})();
</script>
{/if}

<script>
(function () {
    function closest(el, sel) {
        while (el && el !== document) {
            if (el.matches && el.matches(sel)) {
                return el;
            }
            el = el.parentNode;
        }
        return null;
    }

    function post(url, body, cb) {
        var x = new XMLHttpRequest();
        x.open('POST', url, true);
        x.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        x.onreadystatechange = function () {
            if (x.readyState !== 4) {
                return;
            }
            var j = null;
            try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
            cb(j);
        };
        x.send(body);
    }

    function doDelete(btn) {
        post('{$_url}plugin/cpchatAdminDelete', 'id=' + encodeURIComponent(btn.getAttribute('data-id')), function (res) {
            if (res && res.success) {
                var tr = closest(btn, 'tr');
                if (tr && tr.parentNode) {
                    tr.parentNode.removeChild(tr);
                }
                if (window.Swal) {
                    Swal.fire({
                        icon: 'success',
                        title: '{Lang::T('Deleted')}',
                        position: 'top-end',
                        showConfirmButton: false,
                        timer: 5000,
                        timerProgressBar: true,
                        didOpen: function (toast) {
                            toast.addEventListener('mouseenter', Swal.stopTimer);
                            toast.addEventListener('mouseleave', Swal.resumeTimer);
                        }
                    });
                }
                if (!document.querySelector('.cpchat-row-link')) {
                    window.location.reload();
                }
            } else if (window.Swal) {
                Swal.fire({
                    icon: 'error',
                    title: '{Lang::T('Delete failed')}',
                    position: 'top-end',
                    showConfirmButton: false,
                    timer: 5000,
                    timerProgressBar: true
                });
            }
        });
    }

    document.addEventListener('click', function (ev) {
        var del = closest(ev.target, '.cpchat-del');
        if (del) {
            ev.preventDefault();
            ev.stopPropagation();
            if (window.Swal) {
                Swal.fire({
                    icon: 'warning',
                    title: '{Lang::T('Delete this chat permanently?')}',
                    showCancelButton: true,
                    confirmButtonColor: '#dd4b39',
                    confirmButtonText: '{Lang::T('Delete')}',
                    cancelButtonText: '{Lang::T('Cancel')}'
                }).then(function (r) {
                    if (r.isConfirmed) {
                        doDelete(del);
                    }
                });
            } else if (confirm('{Lang::T('Delete this chat permanently?')}')) {
                doDelete(del);
            }
            return;
        }
        var tr = closest(ev.target, 'tr.cpchat-row-link');
        if (tr && !closest(ev.target, 'a,button')) {
            window.location.href = tr.getAttribute('data-url');
        }
    });
})();
</script>

{include file="sections/footer.tpl"}
