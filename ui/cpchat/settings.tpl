{include file="sections/header.tpl"}

<div class="row">
    <div class="col-sm-12 col-md-12">
        <div class="panel panel-primary panel-hovered panel-stacked mb30">
            <div class="panel-heading">
                {Lang::T('Captive Portal Chat Settings')}
                <div class="btn-group pull-right">
                    <a href="{$_url}plugin/captivePortalChat" class="btn btn-default btn-xs"><i class="fa fa-dashboard"></i> {Lang::T('Dashboard')}</a>
                    <a href="{$_url}plugin/captivePortalChatInbox" class="btn btn-default btn-xs"><i class="fa fa-inbox"></i> {Lang::T('Inbox')}</a>
                </div>
            </div>
            <div class="panel-body">

                {if $install_error neq ''}
                    <div class="alert alert-danger">
                        {Lang::T('Chat tables could not be created')}: {$install_error|escape:'html'}
                    </div>
                {/if}

                <ul class="nav nav-tabs">
                    <li class="active"><a data-toggle="tab" href="#tabGeneral">{Lang::T('General')}</a></li>
                    <li><a data-toggle="tab" href="#tabHours">{Lang::T('Support hours')}</a></li>
                    <li><a data-toggle="tab" href="#tabModeration">{Lang::T('Tags &amp; Closure')}</a></li>
                    <li><a data-toggle="tab" href="#tabCanned">{Lang::T('Canned replies')}</a></li>
                    <li><a data-toggle="tab" href="#tabSpam">{Lang::T('Spam protection')}</a></li>
                    <li><a data-toggle="tab" href="#tabSetup">{Lang::T('Installation')}</a></li>
                </ul>

                <div class="tab-content" style="padding-top:15px;">

                    <div id="tabGeneral" class="tab-pane active">
                        <form method="post" action="{$_url}plugin/captivePortalChatSettings">
                            <input type="hidden" name="cpchat_form" value="general">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="form-group">
                                        <label>{Lang::T('Enable chat widget')}</label>
                                        <select name="cpchat_enabled" class="form-control">
                                            <option value="yes"{if $s.enabled} selected{/if}>{Lang::T('Enabled')}</option>
                                            <option value="no"{if !$s.enabled} selected{/if}>{Lang::T('Disabled')}</option>
                                        </select>
                                        <p class="help-block">{Lang::T('When disabled the captive portal button disappears and the API stops accepting chats.')}</p>
                                    </div>
                                    <div class="form-group">
                                        <label>{Lang::T('Button title')}</label>
                                        <input type="text" name="cpchat_title" class="form-control" value="{$s.title|escape:'html'}" maxlength="80">
                                    </div>
                                    <div class="form-group">
                                        <label>{Lang::T('Support name')}</label>
                                        <input type="text" name="cpchat_agent" class="form-control" value="{$s.agent|escape:'html'}" maxlength="60">
                                    </div>
                                    <div class="form-group">
                                        <label>{Lang::T('Welcome message')}</label>
                                        <textarea name="cpchat_welcome" class="form-control" rows="3" maxlength="300">{$s.welcome|escape:'html'}</textarea>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="row">
                                        <div class="col-xs-4">
                                            <div class="form-group">
                                                <label>{Lang::T('Chat open (sec)')}</label>
                                                <input type="number" name="cpchat_poll_open" class="form-control" min="2" max="120" value="{$s.poll_open}">
                                            </div>
                                        </div>
                                        <div class="col-xs-4">
                                            <div class="form-group">
                                                <label>{Lang::T('Chat closed (sec)')}</label>
                                                <input type="number" name="cpchat_poll_closed" class="form-control" min="10" max="600" value="{$s.poll_closed}">
                                            </div>
                                        </div>
                                        <div class="col-xs-4">
                                            <div class="form-group">
                                                <label>{Lang::T('Admin poll (sec)')}</label>
                                                <input type="number" name="cpchat_poll_admin" class="form-control" min="5" max="300" value="{$s.poll_admin}">
                                            </div>
                                        </div>
                                    </div>
                                    <div class="form-group">
                                        <label>{Lang::T('Max message length')}</label>
                                        <input type="number" name="cpchat_max_length" class="form-control" min="100" max="2000" value="{$s.max_length}">
                                    </div>
                                    <div class="form-group">
                                        <label>{Lang::T('Notification sound')}</label>
                                        <select name="cpchat_sound" class="form-control">
                                            <option value="yes"{if $s.sound} selected{/if}>{Lang::T('On')}</option>
                                            <option value="no"{if !$s.sound} selected{/if}>{Lang::T('Off')}</option>
                                        </select>
                                    </div>
                                    <div class="form-group">
                                        <div class="row">
                                            <div class="col-xs-8 text-muted">{Lang::T('Routers seen so far')}</div>
                                            <div class="col-xs-4 text-right"><b>{$routers|@count}</b></div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div class="form-group">
                                <button type="submit" class="btn btn-primary"><i class="fa fa-save"></i> {Lang::T('Save settings')}</button>
                                <span class="text-muted" style="margin-left:10px;">v{$cpchat_version|escape:'html'}</span>
                            </div>
                        </form>
                    </div>

                    <div id="tabHours" class="tab-pane">
                        <form method="post" action="{$_url}plugin/captivePortalChatSettings">
                            <input type="hidden" name="cpchat_form" value="hours">
                            <p class="help-block">{Lang::T('Outside these hours the widget shows an away message, the inbox shows an Offline badge, and customers are told when you are back.')}</p>
                            <div class="row">
                                <div class="col-md-4">
                                    <div class="form-group">
                                        <label>{Lang::T('Enable support hours')}</label>
                                        <select name="cpchat_hours_enabled" class="form-control">
                                            <option value="yes"{if $s.hours_enabled} selected{/if}>{Lang::T('Enabled')}</option>
                                            <option value="no"{if !$s.hours_enabled} selected{/if}>{Lang::T('Always open')}</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="form-group">
                                        <label>{Lang::T('Open at')}</label>
                                        <input type="time" name="cpchat_hours_start" class="form-control" value="{$s.hours_start|escape:'html'}">
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="form-group">
                                        <label>{Lang::T('Close at')}</label>
                                        <input type="time" name="cpchat_hours_end" class="form-control" value="{$s.hours_end|escape:'html'}">
                                    </div>
                                </div>
                            </div>
                            <div class="form-group">
                                <label>{Lang::T('Working days')}</label>
                                <div>
                                    <label class="checkbox-inline"><input type="checkbox" name="cpchat_hours_days[]" value="1" {if isset($hoursOn[1])}checked{/if}> {Lang::T('Monday')}</label>
                                    <label class="checkbox-inline"><input type="checkbox" name="cpchat_hours_days[]" value="2" {if isset($hoursOn[2])}checked{/if}> {Lang::T('Tuesday')}</label>
                                    <label class="checkbox-inline"><input type="checkbox" name="cpchat_hours_days[]" value="3" {if isset($hoursOn[3])}checked{/if}> {Lang::T('Wednesday')}</label>
                                    <label class="checkbox-inline"><input type="checkbox" name="cpchat_hours_days[]" value="4" {if isset($hoursOn[4])}checked{/if}> {Lang::T('Thursday')}</label>
                                    <label class="checkbox-inline"><input type="checkbox" name="cpchat_hours_days[]" value="5" {if isset($hoursOn[5])}checked{/if}> {Lang::T('Friday')}</label>
                                    <label class="checkbox-inline"><input type="checkbox" name="cpchat_hours_days[]" value="6" {if isset($hoursOn[6])}checked{/if}> {Lang::T('Saturday')}</label>
                                    <label class="checkbox-inline"><input type="checkbox" name="cpchat_hours_days[]" value="7" {if isset($hoursOn[7])}checked{/if}> {Lang::T('Sunday')}</label>
                                </div>
                            </div>
                            <div class="form-group">
                                <label>{Lang::T('Away message')}</label>
                                <textarea name="cpchat_away_message" class="form-control" rows="3" maxlength="300">{$s.away_message|escape:'html'}</textarea>
                                <p class="help-block">{Lang::T('Shown in the widget and posted into new chats while the team is offline. Current label:')} <b>{$hours_label|escape:'html'}</b></p>
                            </div>
                            <div class="form-group">
                                <button type="submit" class="btn btn-primary"><i class="fa fa-save"></i> {Lang::T('Save settings')}</button>
                            </div>
                        </form>
                    </div>

                    <div id="tabModeration" class="tab-pane">
                        <form method="post" action="{$_url}plugin/captivePortalChatSettings">
                            <input type="hidden" name="cpchat_form" value="moderation">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="form-group">
                                        <label>{Lang::T('Tag presets')}</label>
                                        <input type="text" name="cpchat_tags" class="form-control" value="{$s.tags|escape:'html'}">
                                        <p class="help-block">{Lang::T('Comma separated. Agents pick from this list in the inbox; tags already used stay available.')}</p>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="form-group">
                                        <label>{Lang::T('Close reasons')}</label>
                                        <input type="text" name="cpchat_close_reasons" class="form-control" value="{$s.close_reasons|escape:'html'}">
                                        <p class="help-block">{Lang::T('Comma separated. Shown in the dialog an agent picks when closing a chat.')}</p>
                                    </div>
                                </div>
                            </div>
                            <div class="form-group">
                                <label>{Lang::T('Currently used tags')}</label>
                                <div>
                                    {foreach $tagOptions as $t}<span class="label label-default" style="margin-right:2px;">{$t|escape:'html'}</span>{/foreach}
                                </div>
                            </div>
                            <div class="form-group">
                                <button type="submit" class="btn btn-primary"><i class="fa fa-save"></i> {Lang::T('Save settings')}</button>
                            </div>
                        </form>
                    </div>

                    <div id="tabCanned" class="tab-pane">
                        <div class="row">
                            <div class="col-md-5">
                                <form method="post" action="{$_url}plugin/captivePortalChatSettings">
                                    <input type="hidden" name="action" value="canned_add">
                                    <input type="hidden" name="canned_id" id="cannedId" value="0">
                                    <div class="form-group">
                                        <label>{Lang::T('Title')}</label>
                                        <input type="text" name="canned_title" id="cannedTitle" class="form-control" maxlength="60">
                                    </div>
                                    <div class="form-group">
                                        <label>{Lang::T('Message')}</label>
                                        <textarea name="canned_body" id="cannedBody" class="form-control" rows="5" maxlength="1000"></textarea>
                                    </div>
                                    <button type="submit" class="btn btn-primary"><i class="fa fa-save"></i> {Lang::T('Save reply')}</button>
                                    <button type="button" class="btn btn-default" id="cannedReset">{Lang::T('New')}</button>
                                </form>
                            </div>
                            <div class="col-md-7">
                                <div class="table-responsive">
                                <table class="table table-bordered table-striped table-condensed">
                                    <thead>
                                        <tr>
                                            <th>{Lang::T('Title')}</th>
                                            <th>{Lang::T('Message')}</th>
                                            <th class="text-right">{Lang::T('Actions')}</th>
                                        </tr>
                                    </thead>
                                    <tbody id="cannedRows">
                                        {foreach $canned as $k}
                                            <tr>
                                                <td>{$k.title|escape:'html'}</td>
                                                <td>{$k.body|escape:'html'|truncate:90}</td>
                                                <td class="text-right">
                                                    <button type="button" class="btn btn-default btn-xs cpchat-edit"
                                                        data-id="{$k.id}" data-title="{$k.title|escape:'html'}" data-body="{$k.body|escape:'html'}">
                                                        <i class="fa fa-pencil"></i>
                                                    </button>
                                                    <form method="post" action="{$_url}plugin/captivePortalChatSettings" style="display:inline;">
                                                        <input type="hidden" name="action" value="canned_delete">
                                                        <input type="hidden" name="canned_id" value="{$k.id}">
                                                        <button type="submit" class="btn btn-danger btn-xs"><i class="fa fa-trash"></i></button>
                                                    </form>
                                                </td>
                                            </tr>
                                        {/foreach}
                                        {if $canned|@count eq 0}
                                            <tr><td colspan="3" class="text-muted text-center">{Lang::T('No canned replies yet')}</td></tr>
                                        {/if}
                                    </tbody>
                                </table>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div id="tabSpam" class="tab-pane">
                        <form method="post" action="{$_url}plugin/captivePortalChatSettings">
                            <input type="hidden" name="cpchat_form" value="spam">
                            <div class="row">
                                <div class="col-md-6">
                                    <div style="margin-bottom:18px;">
                                        <label><input type="checkbox" name="cpchat_spam_honeypot" value="yes" {if $s.spam_honeypot}checked{/if}> <b>{Lang::T('Honeypot field')}</b></label>
                                        <p class="help-block" style="margin:2px 0 0;">{Lang::T('Hidden form field. Bots fill it, humans never see it.')}</p>
                                    </div>
                                    <div style="margin-bottom:18px;">
                                        <label><input type="checkbox" name="cpchat_spam_captcha" value="yes" {if $s.spam_captcha}checked{/if}> <b>{Lang::T('Math captcha')}</b></label>
                                        <p class="help-block" style="margin:2px 0 0;">{Lang::T('Simple sum before a chat can start. No external service.')}</p>
                                    </div>
                                    <div style="margin-bottom:18px;">
                                        <label><input type="checkbox" name="cpchat_spam_strip_links" value="yes" {if $s.spam_strip_links}checked{/if}> <b>{Lang::T('Strip links')}</b></label>
                                        <p class="help-block" style="margin:2px 0 0;">{Lang::T('Replace URLs and e-mails in customer messages with a placeholder.')}</p>
                                    </div>
                                    <div style="margin-bottom:18px;">
                                        <label><input type="checkbox" name="cpchat_spam_auto_block" value="yes" {if $s.spam_auto_block}checked{/if}> <b>{Lang::T('Auto block')}</b></label>
                                        <p class="help-block" style="margin:2px 0 0;">{Lang::T('Block the IP and MAC after repeated offences within an hour.')}</p>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <h4>{Lang::T('Rate limits')}</h4>
                                    <div class="row">
                                        <div class="col-xs-6">
                                            <div class="form-group">
                                                <label>{Lang::T('Max chats per hour / IP')}</label>
                                                <input type="number" name="cpchat_spam_max_chats" class="form-control" min="1" max="100" value="{$s.spam_max_chats}">
                                            </div>
                                        </div>
                                        <div class="col-xs-6">
                                            <div class="form-group">
                                                <label>{Lang::T('Start cooldown (sec)')}</label>
                                                <input type="number" name="cpchat_spam_cooldown" class="form-control" min="0" max="3600" value="{$s.spam_cooldown}">
                                            </div>
                                        </div>
                                    </div>
                                    <div class="row">
                                        <div class="col-xs-6">
                                            <div class="form-group">
                                                <label>{Lang::T('Max messages / 5 min')}</label>
                                                <input type="number" name="cpchat_spam_max_msgs" class="form-control" min="5" max="1000" value="{$s.spam_max_msgs}">
                                            </div>
                                        </div>
                                        <div class="col-xs-6">
                                            <div class="form-group">
                                                <label>{Lang::T('Block duration (h)')}</label>
                                                <input type="number" name="cpchat_spam_block_hours" class="form-control" min="1" max="720" value="{$s.spam_block_hours}">
                                            </div>
                                        </div>
                                    </div>
                                    <p class="help-block">{Lang::T('Chats marked as spam')}: <b>{$stats.spam|default:0}</b></p>
                                </div>
                            </div>
                            <div class="form-group">
                                <button type="submit" class="btn btn-primary"><i class="fa fa-save"></i> {Lang::T('Save settings')}</button>
                            </div>
                        </form>

                        <hr>

                        <div class="row">
                            <div class="col-md-5">
                                <h4>{Lang::T('Manual block')}</h4>
                                <form method="post" action="{$_url}plugin/captivePortalChatSettings">
                                    <input type="hidden" name="action" value="block_add">
                                    <div class="row">
                                        <div class="col-xs-5">
                                            <div class="form-group">
                                                <label>{Lang::T('Type')}</label>
                                                <select name="block_type" class="form-control">
                                                    <option value="ip">{Lang::T('IP address')}</option>
                                                    <option value="mac">{Lang::T('MAC address')}</option>
                                                    <option value="phone">{Lang::T('Phone number')}</option>
                                                </select>
                                            </div>
                                        </div>
                                        <div class="col-xs-7">
                                            <div class="form-group">
                                                <label>{Lang::T('Value')}</label>
                                                <input type="text" name="block_value" class="form-control" placeholder="{Lang::T('value')}" maxlength="60">
                                            </div>
                                        </div>
                                    </div>
                                    <div class="form-group">
                                        <label>{Lang::T('Block for (hours)')}</label>
                                        <input type="number" name="block_hours" class="form-control" min="1" max="720" value="{$s.spam_block_hours}">
                                    </div>
                                    <button type="submit" class="btn btn-danger">{Lang::T('Block')}</button>
                                </form>
                            </div>
                            <div class="col-md-7">
                                <h4>{Lang::T('Blocklist')}</h4>
                                <div class="table-responsive">
                                <table class="table table-bordered table-striped table-condensed">
                                    <thead>
                                        <tr>
                                            <th>{Lang::T('Type')}</th>
                                            <th>{Lang::T('Value')}</th>
                                            <th>{Lang::T('Reason')}</th>
                                            <th class="text-right">{Lang::T('Until')}</th>
                                            <th class="text-right">{Lang::T('Actions')}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {foreach $blocked as $b}
                                            <tr>
                                                <td>{$b.type|escape:'html'}</td>
                                                <td><code>{$b.value|escape:'html'}</code></td>
                                                <td><small>{$b.reason|escape:'html'|truncate:24}</small></td>
                                                <td class="text-right"><small style="white-space:nowrap;">{if $b.expires_at}{Lang::dateTimeFormat($b.expires_at)}{else}{Lang::T('forever')}{/if}</small></td>
                                                <td class="text-right">
                                                    <form method="post" action="{$_url}plugin/captivePortalChatSettings" style="display:inline;">
                                                        <input type="hidden" name="action" value="block_delete">
                                                        <input type="hidden" name="block_id" value="{$b.id}">
                                                        <button type="submit" class="btn btn-default btn-xs">{Lang::T('Unblock')}</button>
                                                    </form>
                                                </td>
                                            </tr>
                                        {/foreach}
                                        {if $blocked|@count eq 0}
                                            <tr><td colspan="5" class="text-muted text-center">{Lang::T('Nothing is blocked')}</td></tr>
                                        {/if}
                                    </tbody>
                                </table>
                                </div>
                            </div>
                        </div>

                        <h4>{Lang::T('Recent rejected attempts')}</h4>
                        <div class="table-responsive">
                        <table class="table table-bordered table-striped table-condensed">
                            <thead>
                                <tr>
                                    <th>{Lang::T('IP')}</th>
                                    <th>{Lang::T('MAC')}</th>
                                    <th>{Lang::T('Reason')}</th>
                                    <th>{Lang::T('Detail')}</th>
                                    <th class="text-right">{Lang::T('Time')}</th>
                                </tr>
                            </thead>
                            <tbody>
                                {foreach $spamlog as $l}
                                    <tr>
                                        <td><code>{$l.ip|escape:'html'|default:'-'}</code></td>
                                        <td><small>{$l.mac|escape:'html'|default:'-'}</small></td>
                                        <td><span class="label label-warning">{$l.reason|escape:'html'}</span></td>
                                        <td><small>{$l.detail|escape:'html'|truncate:60}</small></td>
                                        <td class="text-right"><small style="white-space:nowrap;">{Lang::dateTimeFormat($l.created_at)}</small></td>
                                    </tr>
                                {/foreach}
                                {if $spamlog|@count eq 0}
                                    <tr><td colspan="5" class="text-muted text-center">{Lang::T('No spam attempts logged')}</td></tr>
                                {/if}
                            </tbody>
                        </table>
                        </div>
                        <form method="post" action="{$_url}plugin/captivePortalChatSettings">
                            <input type="hidden" name="action" value="spam_clear">
                            <button type="submit" class="btn btn-default btn-sm"><i class="fa fa-trash"></i> {Lang::T('Clear entries older than 1 day')}</button>
                        </form>
                    </div>

                    <div id="tabSetup" class="tab-pane">
                        <div class="row">
                            <div class="col-md-5">
                                <h4>{Lang::T('Navbar notification')}</h4>
                                <p>
                                    {if $navbar_state.status eq 'installed'}
                                        <span class="label label-success">{Lang::T('Installed')}</span>
                                    {else}
                                        <span class="label label-warning">{Lang::T('Not installed')}</span>
                                    {/if}
                                </p>
                                <p class="text-muted" style="word-break:break-all;">{$navbar_state.file|escape:'html'}</p>
                                <p>{Lang::T('Adds the chat bell with unread counter, popup and browser notification to the admin top navbar.')}</p>
                                {if !$navbar_state.writable}
                                    <div class="alert alert-warning">{Lang::T('The template file is not writable by the web server user.')}</div>
                                {/if}
                                <form method="post" action="{$_url}plugin/captivePortalChatSettings" style="display:inline;">
                                    <input type="hidden" name="action" value="navbar_on">
                                    <button type="submit" class="btn btn-success btn-sm" {if $navbar_state.status eq 'installed' || !$navbar_state.writable}disabled{/if}>
                                        <i class="fa fa-bell"></i> {Lang::T('Install bell')}
                                    </button>
                                </form>
                                <form method="post" action="{$_url}plugin/captivePortalChatSettings" style="display:inline;">
                                    <input type="hidden" name="action" value="navbar_off">
                                    <button type="submit" class="btn btn-default btn-sm" {if $navbar_state.status neq 'installed'}disabled{/if}>
                                        <i class="fa fa-bell-slash"></i> {Lang::T('Remove bell')}
                                    </button>
                                </form>
                                <hr>
                                <div class="row text-center">
                                    <div class="col-xs-3"><b>{$stats.open|default:0}</b><br><small>{Lang::T('Open')}</small></div>
                                    <div class="col-xs-3"><b>{$stats.closed|default:0}</b><br><small>{Lang::T('Closed')}</small></div>
                                    <div class="col-xs-3"><b>{$stats.unread|default:0}</b><br><small>{Lang::T('Unread')}</small></div>
                                    <div class="col-xs-3"><b>{$stats.messages|default:0}</b><br><small>{Lang::T('Messages')}</small></div>
                                </div>
                            </div>
                            <div class="col-md-7">
                                <h4>{Lang::T('Captive portal snippet')}</h4>
                                <p>{Lang::T('Paste one block into each MikroTik hotspot template file, right before the closing body tag. The billing server must be reachable before login (hotspot walled garden / IP bindings).')}</p>
                                <ul class="nav nav-tabs">
                                    <li class="active"><a data-toggle="tab" href="#tabLogin">login.html</a></li>
                                    <li><a data-toggle="tab" href="#tabLogout">logout.html</a></li>
                                    <li><a data-toggle="tab" href="#tabStatus">status.html</a></li>
                                </ul>
                                <div class="tab-content" style="padding-top:10px;">
                                    <div id="tabLogin" class="tab-pane active">
                                        <textarea class="form-control" id="snipLogin" rows="6" readonly style="font-family:monospace;font-size:12px;">{$snippet_login|escape:'html'}</textarea>
                                        <button type="button" class="btn btn-default btn-sm" style="margin-top:6px;" data-copy="snipLogin"><i class="fa fa-copy"></i> {Lang::T('Copy')}</button>
                                    </div>
                                    <div id="tabLogout" class="tab-pane">
                                        <textarea class="form-control" id="snipLogout" rows="6" readonly style="font-family:monospace;font-size:12px;">{$snippet_logout|escape:'html'}</textarea>
                                        <button type="button" class="btn btn-default btn-sm" style="margin-top:6px;" data-copy="snipLogout"><i class="fa fa-copy"></i> {Lang::T('Copy')}</button>
                                    </div>
                                    <div id="tabStatus" class="tab-pane">
                                        <textarea class="form-control" id="snipStatus" rows="6" readonly style="font-family:monospace;font-size:12px;">{$snippet_status|escape:'html'}</textarea>
                                        <button type="button" class="btn btn-default btn-sm" style="margin-top:6px;" data-copy="snipStatus"><i class="fa fa-copy"></i> {Lang::T('Copy')}</button>
                                    </div>
                                </div>
                                <div class="callout callout-info" style="margin-top:10px;">
                                    <p style="font-size:12px;">
                                        <b>{Lang::T('Notes')}</b><br>
                                        &bull; {Lang::T('MikroTik replaces $(mac), $(ip), $(username) and $(hostname) when the page is served.')}<br>
                                        &bull; {Lang::T('Per router filters work out of the box: the snippet sends $(hostname).')}<br>
                                        &bull; {Lang::T('Keep the same chat button on all three pages so the conversation continues after login.')}
                                    </p>
                                </div>
                            </div>
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
    if (window.location.hash && window.jQuery) {
        var tabLink = document.querySelector('.nav-tabs a[href="' + window.location.hash + '"]');
        if (tabLink) { jQuery(tabLink).tab('show'); }
    }
    var btns = document.querySelectorAll('[data-copy]');
    for (var i = 0; i < btns.length; i++) {
        btns[i].onclick = function () {
            var t = document.getElementById(this.getAttribute('data-copy'));
            t.select();
            try {
                document.execCommand('copy');
                this.innerHTML = '<i class="fa fa-check"></i> Copied';
            } catch (e) {
                this.innerHTML = '<i class="fa fa-exclamation"></i> Select and copy manually';
            }
            var self = this;
            setTimeout(function () {
                self.innerHTML = '<i class="fa fa-copy"></i> Copy';
            }, 2500);
        };
    }

    var edits = document.querySelectorAll('.cpchat-edit');
    for (var e = 0; e < edits.length; e++) {
        edits[e].onclick = function () {
            document.getElementById('cannedId').value = this.getAttribute('data-id');
            document.getElementById('cannedTitle').value = this.getAttribute('data-title');
            document.getElementById('cannedBody').value = this.getAttribute('data-body');
            document.getElementById('cannedTitle').focus();
        };
    }
    var reset = document.getElementById('cannedReset');
    if (reset) {
        reset.onclick = function () {
            document.getElementById('cannedId').value = '0';
            document.getElementById('cannedTitle').value = '';
            document.getElementById('cannedBody').value = '';
        };
    }
})();
</script>
{/literal}

{include file="sections/footer.tpl"}
