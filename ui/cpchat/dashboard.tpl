{include file="sections/header.tpl"}

<div class="row">
    <div class="col-sm-12 col-md-12">
        <div class="panel panel-primary panel-hovered panel-stacked mb30">
            <div class="panel-heading">
                {Lang::T('Captive Portal Chat')}
                <div class="btn-group pull-right">
                    {if $open_now}
                        <span class="label label-success" style="margin-right:6px;"><i class="fa fa-circle"></i> {Lang::T('Online')}</span>
                    {else}
                        <span class="label label-warning" style="margin-right:6px;" title="{$hours_label|escape:'html'}"><i class="fa fa-moon-o"></i> {Lang::T('Offline')}</span>
                    {/if}
                    <a href="{$_url}plugin/captivePortalChatInbox" class="btn btn-primary btn-xs"><i class="fa fa-inbox"></i> {Lang::T('Open Inbox')}</a>
                    <a href="{$_url}plugin/captivePortalChatSettings" class="btn btn-default btn-xs"><i class="fa fa-cog"></i> {Lang::T('Settings')}</a>
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
                {if !$s.enabled}
                    <div class="alert alert-info">
                        {Lang::T('Chat is currently disabled. Customers cannot start new chats.')}
                        <a href="{$_url}plugin/captivePortalChatSettings" class="btn btn-default btn-xs" style="margin-left:10px;">{Lang::T('Enable it')}</a>
                    </div>
                {/if}

                <div class="row">
                    <div class="col-lg-3 col-xs-6">
                        <div class="small-box bg-aqua">
                            <div class="inner">
                                <h4 class="text-bold" style="font-size: large;">{$stats.open|default:0}</h4>
                            </div>
                            <div class="icon">
                                <i class="fa fa-comments-o"></i>
                            </div>
                            <div class="small-box-footer">{Lang::T('Open chats')}</div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-xs-6">
                        <div class="small-box bg-yellow">
                            <div class="inner">
                                <h4 class="text-bold" style="font-size: large;">{$stats.waiting|default:0}</h4>
                            </div>
                            <div class="icon">
                                <i class="fa fa-clock-o"></i>
                            </div>
                            <div class="small-box-footer">{Lang::T('Waiting for a reply')}</div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-xs-6">
                        <div class="small-box bg-red">
                            <div class="inner">
                                <h4 class="text-bold" style="font-size: large;">{$stats.unread|default:0}</h4>
                            </div>
                            <div class="icon">
                                <i class="fa fa-bell-o"></i>
                            </div>
                            <div class="small-box-footer">{Lang::T('Unread messages')}</div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-xs-6">
                        <div class="small-box bg-green">
                            <div class="inner">
                                <h4 class="text-bold" style="font-size: large;">{$stats.today|default:0}</h4>
                            </div>
                            <div class="icon">
                                <i class="fa fa-plus"></i>
                            </div>
                            <div class="small-box-footer">{Lang::T('Chats started today')}</div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-xs-6">
                        <div class="small-box bg-teal">
                            <div class="inner">
                                <h4 class="text-bold" style="font-size: large;">{$stats.closed|default:0}</h4>
                            </div>
                            <div class="icon">
                                <i class="fa fa-check"></i>
                            </div>
                            <div class="small-box-footer">{Lang::T('Closed chats')}</div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-xs-6">
                        <div class="small-box bg-purple">
                            <div class="inner">
                                <h4 class="text-bold" style="font-size: large;">{if $stats.avg_first_reply !== null}{$stats.avg_first_reply} {Lang::T('min')}{else}&ndash;{/if}</h4>
                            </div>
                            <div class="icon">
                                <i class="fa fa-clock-o"></i>
                            </div>
                            <div class="small-box-footer">{Lang::T('Average first reply')}</div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-xs-6">
                        <div class="small-box bg-maroon">
                            <div class="inner">
                                <h4 class="text-bold" style="font-size: large;">{$spam.hits_24h|default:0}</h4>
                            </div>
                            <div class="icon">
                                <i class="fa fa-shield"></i>
                            </div>
                            <div class="small-box-footer">{Lang::T('Blocked attempts (24h)')}</div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-xs-6">
                        <div class="small-box bg-gray">
                            <div class="inner">
                                <h4 class="text-bold" style="font-size: large;">{$stats.messages|default:0}</h4>
                            </div>
                            <div class="icon">
                                <i class="fa fa-comments"></i>
                            </div>
                            <div class="small-box-footer">{Lang::T('Messages in total')}</div>
                        </div>
                    </div>
                </div>

                <div class="row">
                    <div class="col-md-8">
                        <div class="panel panel-default mb20">
                            <div class="panel-heading"><i class="fa fa-bar-chart"></i> {Lang::T('Last 14 days')}</div>
                            <div class="panel-body">
                                <div id="cpchatChart"></div>
                                {if $chart_empty}
                                    <p class="text-muted text-center" style="margin-top:10px;">{Lang::T('No chats or messages in the last 14 days')}</p>
                                {/if}
                            </div>
                        </div>
                    </div>

                    <div class="col-md-4">
                        {* Per-router breakdown: hidden for now, bring back later
                        <div class="panel panel-default mb20">
                            <div class="panel-heading"><i class="fa fa-server"></i> {Lang::T('Per router')}</div>
                            <div class="panel-body" style="padding:0;">
                                <table class="table table-bordered table-striped table-condensed" style="margin:0;">
                                    <thead>
                                        <tr>
                                            <th>{Lang::T('Router')}</th>
                                            <th class="text-right">{Lang::T('Chats')}</th>
                                            <th class="text-right">{Lang::T('Open')}</th>
                                            <th class="text-right">{Lang::T('Last')}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {foreach $routers as $r}
                                            <tr>
                                                <td><a href="{$_url}plugin/captivePortalChatInbox&router={$r.router|escape:'url'}">{$r.router|escape:'html'|truncate:24}</a></td>
                                                <td class="text-right">{$r.chats}</td>
                                                <td class="text-right">{$r.open_chats}</td>
                                                <td class="text-right"><small>{if $r.last_at}{$r.last_at|date_format:'%d/%m %H:%i'}{else}&ndash;{/if}</small></td>
                                            </tr>
                                        {/foreach}
                                        {if $routers|@count eq 0}
                                            <tr><td colspan="4" class="text-muted text-center">{Lang::T('No data yet')}</td></tr>
                                        {/if}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        *}

                        <div class="panel panel-default mb20">
                            <div class="panel-heading"><i class="fa fa-user"></i> {Lang::T('Agent workload')}</div>
                            <div class="panel-body" style="padding:0;">
                                <table class="table table-bordered table-striped table-condensed" style="margin:0;">
                                    <thead>
                                        <tr>
                                            <th>{Lang::T('Agent')}</th>
                                            <th class="text-right">{Lang::T('Chats')}</th>
                                            <th class="text-right">{Lang::T('Open')}</th>
                                            <th class="text-right">{Lang::T('Unread')}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {foreach $workload as $w}
                                            <tr>
                                                <td><a href="{$_url}plugin/captivePortalChatInbox&assigned={$w.id}">{$w.name|escape:'html'}</a> <small class="text-muted">{$w.type|escape:'html'}</small></td>
                                                <td class="text-right">{$w.total}</td>
                                                <td class="text-right">{$w.open_chats}</td>
                                                <td class="text-right">{$w.unread}</td>
                                            </tr>
                                        {/foreach}
                                        {if $workload|@count eq 0}
                                            <tr><td colspan="4" class="text-muted text-center">{Lang::T('No active agents')}</td></tr>
                                        {/if}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="row">
                    <div class="col-md-8">
                        <div class="panel panel-default mb20">
                            <div class="panel-heading">
                                <i class="fa fa-inbox"></i> {Lang::T('Latest chats')}
                                <div class="btn-group pull-right">
                                    <a class="btn btn-default btn-xs" href="{$_url}plugin/captivePortalChatInbox">{Lang::T('All chats')}</a>
                                </div>
                            </div>
                            <div class="panel-body" style="padding:0;">
                                <div class="table-responsive">
                                <table class="table table-bordered table-striped table-condensed" style="margin:0;">
                                    <thead>
                                        <tr>
                                            <th>{Lang::T('Customer')}</th>
                                            <th>{Lang::T('Last message')}</th>
                                            <th>{Lang::T('Tags')}</th>
                                            <th>{Lang::T('Agent')}</th>
                                            <th class="text-right">{Lang::T('Time')}</th>
                                            <th class="text-right">{Lang::T('Actions')}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {foreach $latest as $c}
                                            <tr class="cpchat-row-link" data-url="{$_url}plugin/captivePortalChatInbox&id={$c.id}">
                                                <td>
                                                    <a href="{$_url}plugin/captivePortalChatInbox&id={$c.id}">{$c.name|escape:'html'}</a>
                                                    <small class="text-muted">{$c.phone|escape:'html'}</small>
                                                    {if $c.status eq 'open'}<span class="label label-success">open</span>{else}<span class="label label-default">closed</span>{/if}
                                                    {if $c.unread_admin > 0}<span class="badge bg-red">{$c.unread_admin}</span>{/if}
                                                </td>
                                                <td>{$c.last_body|escape:'html'|truncate:70}</td>
                                                <td>{foreach $c.tags as $t}<span class="label label-default" style="margin-right:2px;">{$t|escape:'html'}</span>{/foreach}</td>
                                                <td><small>{$c.assigned_name|escape:'html'|default:'&ndash;'}</small></td>
                                                <td class="text-right"><small>{$c.last_dt}</small></td>
                                                <td class="text-right" style="white-space:nowrap;">
                                                    <a href="{$_url}plugin/captivePortalChatInbox&id={$c.id}" class="btn btn-primary btn-xs">{Lang::T('View')}</a>
                                                    <button type="button" class="btn btn-danger btn-xs cpchat-del" data-id="{$c.id}">{Lang::T('Delete')}</button>
                                                </td>
                                            </tr>
                                        {/foreach}
                                        {if $latest|@count eq 0}
                                            <tr><td colspan="6" class="text-muted text-center">{Lang::T('No chats yet. Add the widget snippet to your hotspot login page.')}</td></tr>
                                        {/if}
                                    </tbody>
                                </table>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-md-4">
                        {* Spam protection summary: hidden for now, bring back later
                        <div class="panel panel-default mb20">
                            <div class="panel-heading">
                                <i class="fa fa-shield"></i> {Lang::T('Spam protection')}
                                <div class="btn-group pull-right">
                                    <a class="btn btn-default btn-xs" href="{$_url}plugin/captivePortalChatSettings">{Lang::T('Configure')}</a>
                                </div>
                            </div>
                            <div class="panel-body">
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Rejected in 24h')}</div>
                                    <div class="col-xs-4 text-right"><b>{$spam.hits_24h|default:0}</b></div>
                                </div>
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Currently blocked')}</div>
                                    <div class="col-xs-4 text-right"><b>{$spam.blocked|default:0}</b></div>
                                </div>
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Marked as spam')}</div>
                                    <div class="col-xs-4 text-right"><b>{$stats.spam|default:0}</b></div>
                                </div>
                                {if $spam.reasons|@count > 0}
                                    <div style="margin:8px 0 4px;">
                                        {foreach $spam.reasons as $r}
                                            <span class="label label-warning" style="margin-right:4px;">{$r.reason|escape:'html'}: {$r.n}</span>
                                        {/foreach}
                                    </div>
                                {/if}
                                <table class="table table-bordered table-striped table-condensed" style="margin-top:8px;">
                                    <thead>
                                        <tr>
                                            <th>{Lang::T('IP')}</th>
                                            <th>{Lang::T('Reason')}</th>
                                            <th class="text-right">{Lang::T('Time')}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {foreach $spamlog as $l}
                                            <tr>
                                                <td><code>{$l.ip|escape:'html'|default:'-'}</code></td>
                                                <td>{$l.reason|escape:'html'}</td>
                                                <td class="text-right"><small>{Lang::dateTimeFormat($l.created_at)}</small></td>
                                            </tr>
                                        {/foreach}
                                        {if $spamlog|@count eq 0}
                                            <tr><td colspan="3" class="text-muted text-center">{Lang::T('No blocked attempts')}</td></tr>
                                        {/if}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        *}

                        {* Status box: hidden for now, bring back later
                        <div class="panel panel-default mb20">
                            <div class="panel-heading"><i class="fa fa-info-circle"></i> {Lang::T('Status')}</div>
                            <div class="panel-body">
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Plugin version')}</div>
                                    <div class="col-xs-4 text-right"><b>{$cpchat_version|escape:'html'}</b></div>
                                </div>
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Chat enabled')}</div>
                                    <div class="col-xs-4 text-right"><b>{if $s.enabled}{Lang::T('Yes')}{else}{Lang::T('No')}{/if}</b></div>
                                </div>
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Support hours')}</div>
                                    <div class="col-xs-4 text-right"><b>{if $s.hours_enabled}{$hours_label|escape:'html'}{else}{Lang::T('Always open')}{/if}</b></div>
                                </div>
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Navbar bell')}</div>
                                    <div class="col-xs-4 text-right"><b>{$navbar_state.status|escape:'html'}</b></div>
                                </div>
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Total chats')}</div>
                                    <div class="col-xs-4 text-right"><b>{$stats.total|default:0}</b></div>
                                </div>
                                <div class="row">
                                    <div class="col-xs-8 text-muted">{Lang::T('Last 7 days')}</div>
                                    <div class="col-xs-4 text-right"><b>{$stats.week|default:0}</b></div>
                                </div>
                            </div>
                        </div>
                        *}
                    </div>
                </div>

            </div>
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
