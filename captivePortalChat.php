<?php
$cpchatRoles = ['SuperAdmin', 'Admin'];
// one sidebar entry only: Dashboard is the landing page, Inbox and Settings are reached
// from its breadcrumb + header buttons (the routes themselves still exist)
register_menu("Captive Portal Chat", true, "captivePortalChat", 'AFTER_MESSAGE', 'ion ion-chatbubbles', '', 'success', $cpchatRoles);
unset($cpchatRoles);

/**
 * Bismillahir Rahmanir Rahim
 *
 * Captive Portal Chat Plugin For PHPNuxBill
 *
 * Lets hotspot customers start a chat from the MikroTik captive portal pages
 * (login.html / logout.html / status.html) and lets admins reply from the
 * billing panel. A notification bell is injected into the admin navbar.
 *
 * Pages  : captivePortalChat (dashboard), captivePortalChatInbox, captivePortalChatSettings
 * Public : cpchatWidgetJs, cpchatStart, cpchatSend, cpchatPoll, cpchatClose, cpchatCaptcha
 * Admin  : cpchatAdmin*, cpchatExportCsv, cpchatExportPdf, cpchatNavbarJs, cpchatStyleJs
 *
 * Tables (auto created): tbl_cpchat_conversations, tbl_cpchat_messages,
 *   tbl_cpchat_canned, tbl_cpchat_blocked, tbl_cpchat_spamlog
 * Settings (tbl_appconfig): cpchat_* (enabled, title, welcome, agent, poll_*, sound,
 *   max_length, hours_*, away_message, tags, spam_*)
 *
 * @author systik
 * Contact: https://linktr.ee/systik
 */

$captivePortalChat_version = '2.1.2';

/* ------------------------------------------------------------------ *
 *  Schema
 * ------------------------------------------------------------------ */

function cpchat_schema()
{
    return [
        'tbl_cpchat_conversations' => "CREATE TABLE IF NOT EXISTS tbl_cpchat_conversations (
            id MEDIUMINT NOT NULL AUTO_INCREMENT,
            token CHAR(32) NOT NULL,
            name VARCHAR(60) DEFAULT '',
            phone VARCHAR(24) DEFAULT '',
            mac VARCHAR(17) DEFAULT '',
            ip VARCHAR(45) DEFAULT '',
            username VARCHAR(60) DEFAULT '',
            router VARCHAR(60) DEFAULT '',
            page VARCHAR(15) DEFAULT '',
            status VARCHAR(10) DEFAULT 'open',
            assigned_to MEDIUMINT DEFAULT 0,
            assigned_at DATETIME NULL,
            tags VARCHAR(255) DEFAULT '',
            close_reason VARCHAR(60) DEFAULT '',
            rating TINYINT DEFAULT 0,
            is_spam TINYINT(1) DEFAULT 0,
            first_reply_at DATETIME NULL,
            unread_admin INT DEFAULT 0,
            unread_customer INT DEFAULT 0,
            last_message_id MEDIUMINT DEFAULT 0,
            last_message_at DATETIME NULL,
            customer_seen_id MEDIUMINT DEFAULT 0,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY cpchat_token (token),
            KEY cpchat_mac (mac),
            KEY cpchat_phone (phone),
            KEY cpchat_ip (ip),
            KEY cpchat_status (status),
            KEY cpchat_assigned (assigned_to),
            KEY cpchat_router (router),
            KEY cpchat_updated (updated_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'tbl_cpchat_messages' => "CREATE TABLE IF NOT EXISTS tbl_cpchat_messages (
            id MEDIUMINT NOT NULL AUTO_INCREMENT,
            conversation_id MEDIUMINT NOT NULL,
            sender VARCHAR(10) NOT NULL,
            sender_id MEDIUMINT DEFAULT 0,
            sender_name VARCHAR(60) DEFAULT '',
            body VARCHAR(2000) NOT NULL,
            client_ref CHAR(36) DEFAULT NULL,
            is_read TINYINT(1) DEFAULT 0,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY cpchat_ref (conversation_id, client_ref),
            KEY cpchat_conv (conversation_id, id),
            KEY cpchat_created (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'tbl_cpchat_canned' => "CREATE TABLE IF NOT EXISTS tbl_cpchat_canned (
            id MEDIUMINT NOT NULL AUTO_INCREMENT,
            title VARCHAR(60) DEFAULT '',
            body VARCHAR(1000) NOT NULL,
            sort INT DEFAULT 0,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'tbl_cpchat_blocked' => "CREATE TABLE IF NOT EXISTS tbl_cpchat_blocked (
            id MEDIUMINT NOT NULL AUTO_INCREMENT,
            type VARCHAR(10) NOT NULL,
            value VARCHAR(60) NOT NULL,
            reason VARCHAR(160) DEFAULT '',
            hits INT DEFAULT 1,
            created_at DATETIME NOT NULL,
            expires_at DATETIME NULL,
            PRIMARY KEY (id),
            UNIQUE KEY cpchat_block (type, value)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'tbl_cpchat_spamlog' => "CREATE TABLE IF NOT EXISTS tbl_cpchat_spamlog (
            id MEDIUMINT NOT NULL AUTO_INCREMENT,
            ip VARCHAR(45) DEFAULT '',
            mac VARCHAR(17) DEFAULT '',
            reason VARCHAR(40) NOT NULL,
            detail VARCHAR(200) DEFAULT '',
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY cpchat_spam_time (created_at),
            KEY cpchat_spam_ip (ip)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    ];
}

/** Columns added after v1: existing installs get them with ALTER TABLE */
function cpchat_migrate()
{
    $db = ORM::get_db();
    $wanted = [
        'assigned_to' => "ADD COLUMN assigned_to MEDIUMINT DEFAULT 0",
        'assigned_at' => "ADD COLUMN assigned_at DATETIME NULL",
        'tags' => "ADD COLUMN tags VARCHAR(255) DEFAULT ''",
        'close_reason' => "ADD COLUMN close_reason VARCHAR(60) DEFAULT ''",
        'rating' => "ADD COLUMN rating TINYINT DEFAULT 0",
        'is_spam' => "ADD COLUMN is_spam TINYINT(1) DEFAULT 0",
        'first_reply_at' => "ADD COLUMN first_reply_at DATETIME NULL",
    ];
    $indexes = [
        'cpchat_ip' => "ADD KEY cpchat_ip (ip)",
        'cpchat_assigned' => "ADD KEY cpchat_assigned (assigned_to)",
        'cpchat_router' => "ADD KEY cpchat_router (router)",
    ];
    $columns = [];
    foreach ($db->query("SHOW COLUMNS FROM tbl_cpchat_conversations")->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $columns[$row['Field']] = true;
    }
    foreach ($wanted as $column => $sql) {
        if (!isset($columns[$column])) {
            $db->exec("ALTER TABLE tbl_cpchat_conversations " . $sql);
        }
    }
    $keys = [];
    foreach ($db->query("SHOW INDEX FROM tbl_cpchat_conversations")->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $keys[$row['Key_name']] = true;
    }
    foreach ($indexes as $name => $sql) {
        if (!isset($keys[$name])) {
            try {
                $db->exec("ALTER TABLE tbl_cpchat_conversations " . $sql);
            } catch (Throwable $e) {
                // a duplicate index is harmless
            }
        }
    }
}

/**
 * Create the plugin tables when missing. Idempotent, once per request.
 * @return string|true true on success, error message on failure
 */
function cpchat_install()
{
    static $done = false, $result = true;
    if ($done) {
        return $result;
    }
    $done = true;
    try {
        $db = ORM::get_db();
        foreach (cpchat_schema() as $table => $sql) {
            $exists = $db->query("SHOW TABLES LIKE '" . $table . "'")->fetch();
            if ($exists === false || $exists === null) {
                $db->exec($sql);
            }
        }
        cpchat_migrate();
        $result = true;
    } catch (Throwable $e) {
        $result = $e->getMessage();
    }
    return $result;
}

function cpchat_ready()
{
    $r = cpchat_install();
    return ($r === true);
}

/* ------------------------------------------------------------------ *
 *  Settings
 * ------------------------------------------------------------------ */

/** Raw cpchat_* value from tbl_appconfig with a default */
function cpchat_config($key, $default)
{
    global $config;
    $value = isset($config['cpchat_' . $key]) ? trim((string) $config['cpchat_' . $key]) : '';
    return ($value === '') ? $default : $value;
}

/** Yes/No cpchat_* value */
function cpchat_config_yes($key, $default = false)
{
    global $config;
    if (!isset($config['cpchat_' . $key]) || trim((string) $config['cpchat_' . $key]) === '') {
        return $default;
    }
    return $config['cpchat_' . $key] === 'yes';
}

function cpchat_settings()
{
    global $captivePortalChat_version;
    $s = [
        'enabled' => cpchat_config_yes('enabled', false),
        'title' => cpchat_config('title', ''),
        'welcome' => cpchat_config('welcome', ''),
        'agent' => cpchat_config('agent', ''),
        'poll_open' => max(2, (int) cpchat_config('poll_open', 5)),
        'poll_closed' => max(10, (int) cpchat_config('poll_closed', 20)),
        'poll_admin' => max(5, (int) cpchat_config('poll_admin', 15)),
        'max_length' => min(2000, max(100, (int) cpchat_config('max_length', 1000))),
        'sound' => cpchat_config_yes('sound', true),
        // support hours
        'hours_enabled' => cpchat_config_yes('hours_enabled', false),
        'hours_start' => cpchat_config('hours_start', '08:00'),
        'hours_end' => cpchat_config('hours_end', '20:00'),
        'hours_days' => cpchat_config('hours_days', '1,2,3,4,5,6'),
        'away_message' => cpchat_config('away_message', 'We are offline right now. Leave your question, we will reply as soon as we are back.'),
        // moderation
        'tags' => cpchat_config('tags', 'billing,network,outage,payment,complaint'),
        'close_reasons' => cpchat_config('close_reasons', 'Resolved,Customer not responding,Escalated,Other'),
        // spam protection
        'spam_honeypot' => cpchat_config_yes('spam_honeypot', true),
        'spam_captcha' => cpchat_config_yes('spam_captcha', false),
        'spam_strip_links' => cpchat_config_yes('spam_strip_links', false),
        'spam_max_chats' => max(1, (int) cpchat_config('spam_max_chats', 5)),
        'spam_max_msgs' => max(5, (int) cpchat_config('spam_max_msgs', 40)),
        'spam_cooldown' => max(0, (int) cpchat_config('spam_cooldown', 15)),
        'spam_auto_block' => cpchat_config_yes('spam_auto_block', true),
        'spam_block_hours' => max(1, (int) cpchat_config('spam_block_hours', 24)),
        'version' => $captivePortalChat_version,
    ];
    if ($s['title'] === '') {
        $s['title'] = Lang::T('Need help? Chat with us');
    }
    if ($s['welcome'] === '') {
        $s['welcome'] = 'Hi! Tell us what you need and we will reply here.';
    }
    if ($s['agent'] === '') {
        global $config;
        $s['agent'] = isset($config['CompanyName']) ? $config['CompanyName'] : 'Support';
    }
    return $s;
}

/**
 * Are we inside the configured support hours?
 * The app already calls date_default_timezone_set(), so local time is correct.
 * @return bool true when the team is reachable
 */
function cpchat_is_open()
{
    $s = cpchat_settings();
    if (!$s['hours_enabled']) {
        return true;
    }
    $day = (int) date('N'); // 1 = Monday ... 7 = Sunday
    $days = array_filter(array_map('intval', explode(',', $s['hours_days'])));
    if (!empty($days) && !in_array($day, $days, true)) {
        return false;
    }
    $now = date('H:i');
    $start = strtotime($s['hours_start']) !== false ? date('H:i', strtotime($s['hours_start'])) : '00:00';
    $end = strtotime($s['hours_end']) !== false ? date('H:i', strtotime($s['hours_end'])) : '23:59';
    if ($start <= $end) {
        return ($now >= $start && $now <= $end);
    }
    // window crossing midnight
    return ($now >= $start || $now <= $end);
}

function cpchat_hours_label()
{
    $s = cpchat_settings();
    if (!$s['hours_enabled']) {
        return Lang::T('Always online');
    }
    $names = [1 => 'Mon', 2 => 'Tue', 3 => 'Wed', 4 => 'Thu', 5 => 'Fri', 6 => 'Sat', 7 => 'Sun'];
    $days = array_filter(array_map('intval', explode(',', $s['hours_days'])));
    if (count($days) === 7 || empty($days)) {
        $daysLabel = Lang::T('Every day');
    } else {
        $parts = [];
        foreach ($days as $d) {
            if (isset($names[$d])) {
                $parts[] = $names[$d];
            }
        }
        $daysLabel = implode(', ', $parts);
    }
    return $daysLabel . ' ' . $s['hours_start'] . ' - ' . $s['hours_end'];
}

function cpchat_save_setting($key, $value)
{
    $d = ORM::for_table('tbl_appconfig')->where('setting', $key)->find_one();
    if (!$d) {
        $d = ORM::for_table('tbl_appconfig')->create();
        $d->setting = $key;
    }
    $d->value = $value;
    $d->save();
}

/* ------------------------------------------------------------------ *
 *  Helpers
 * ------------------------------------------------------------------ */

function cpchat_url($function, $params = [])
{
    $url = getUrl('plugin/' . $function);
    if (empty($params)) {
        return $url;
    }
    $sep = (strpos($url, '?') === false) ? '?' : '&';
    return $url . $sep . http_build_query($params);
}

function cpchat_client_ip()
{
    if (!empty($_SERVER['HTTP_CF_CONNECTING_IP'])) {
        return $_SERVER['HTTP_CF_CONNECTING_IP'];
    }
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $parts = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        return trim($parts[0]);
    }
    if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        return $_SERVER['HTTP_CLIENT_IP'];
    }
    return isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '';
}

/** Clean a value coming from a MikroTik template variable like $(mac) */
function cpchat_meta_value($value, $max = 60)
{
    $value = trim((string) $value);
    // unsubstituted hotspot template, or a JS placeholder
    if ($value === '' || $value === 'undefined' || $value === 'null' || strpos($value, '$(') !== false) {
        return '';
    }
    $value = preg_replace('/[^A-Za-z0-9:.+@_\- ]/u', '', $value);
    return mb_substr($value, 0, $max);
}

/** Allow unicode letters, so names are not stripped on localised portals */
function cpchat_clean_name($value, $max = 60)
{
    $value = trim((string) $value);
    if ($value === '' || strpos($value, '$(') !== false) {
        return '';
    }
    $value = preg_replace('/[^\p{L}\p{N}\s.,\-\'+]/u', '', $value);
    $value = preg_replace('/\s+/u', ' ', $value);
    return trim(mb_substr($value, 0, $max));
}

function cpchat_clean_text($value, $max = 1000)
{
    $body = trim((string) $value);
    if ($body === '') {
        return '';
    }
    $body = preg_replace('/\r\n|\r/', "\n", $body);
    $body = str_replace(["\0", "\x0B", "\x1A"], '', $body);
    return mb_substr($body, 0, $max);
}

function cpchat_new_token()
{
    return bin2hex(random_bytes(16));
}

function cpchat_json($data, $status = 200)
{
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type');
        header('Cache-Control: no-store, no-cache, must-revalidate');
        header('X-Content-Type-Options: nosniff');
    }
    if ($status !== 200) {
        http_response_code($status);
    }
    echo json_encode($data);
    exit;
}

function cpchat_error($message, $status = 200)
{
    cpchat_json(['success' => false, 'message' => $message], $status);
}

function cpchat_post_body()
{
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        return $_POST;
    }
    return $_GET;
}

function cpchat_admin()
{
    $admin = Admin::_info();
    if (!$admin) {
        return null;
    }
    return $admin;
}

function cpchat_can_manage($admin)
{
    return $admin && in_array($admin['user_type'], ['SuperAdmin', 'Admin']);
}

function cpchat_message_row($m)
{
    return [
        'id' => (int) $m['id'],
        'conversation_id' => (int) $m['conversation_id'],
        'sender' => $m['sender'],
        'sender_name' => $m['sender_name'],
        'body' => $m['body'],
        'ref' => $m['client_ref'],
        'at' => $m['created_at'],
        'time' => date('H:i', strtotime($m['created_at'])),
    ];
}

/* ------------------------------------------------------------------ *
 *  Data operations
 * ------------------------------------------------------------------ */

function cpchat_find_conversation($token = '', $id = 0)
{
    if ($token !== '') {
        return ORM::for_table('tbl_cpchat_conversations')->where('token', $token)->find_one();
    }
    if ($id > 0) {
        return ORM::for_table('tbl_cpchat_conversations')->find_one($id);
    }
    return null;
}

function cpchat_add_message($conversation_id, $sender, $body, $ref = '', $sender_id = 0, $sender_name = '')
{
    $now = date('Y-m-d H:i:s');
    if ($ref !== '') {
        $dup = ORM::for_table('tbl_cpchat_messages')
            ->where('conversation_id', $conversation_id)
            ->where('client_ref', $ref)
            ->find_one();
        if ($dup) {
            return ['id' => (int) $dup['id'], 'created_at' => $dup['created_at'], 'replay' => true];
        }
    }
    $m = ORM::for_table('tbl_cpchat_messages')->create();
    $m->conversation_id = $conversation_id;
    $m->sender = $sender;
    $m->sender_id = $sender_id;
    $m->sender_name = $sender_name;
    $m->body = $body;
    $m->client_ref = ($ref !== '') ? $ref : null;
    $m->is_read = 0;
    $m->created_at = $now;
    $m->save();

    $c = ORM::for_table('tbl_cpchat_conversations')->find_one($conversation_id);
    if ($c) {
        $c->last_message_id = $m->id();
        $c->last_message_at = $now;
        $c->updated_at = $now;
        if ($sender === 'customer') {
            $c->unread_admin = (int) $c->unread_admin + 1;
        } else {
            $c->unread_customer = (int) $c->unread_customer + 1;
        }
        if ($sender === 'admin' && empty($c->first_reply_at)) {
            $c->first_reply_at = $now;
        }
        $c->save();
    }
    return ['id' => (int) $m->id(), 'created_at' => $now, 'replay' => false];
}

/**
 * Conversation list with the last message preview.
 * $filters: q, status, router, assigned (me|0|unassigned|<id>), tag, spam
 */
function cpchat_conversation_query($filters = [], $limit = 200)
{
    $limit = max(1, min(500, (int) $limit));
    $where = [];
    $params = [];
    $search = isset($filters['q']) ? trim((string) $filters['q']) : '';
    if ($search !== '') {
        $where[] = "(c.name LIKE ? OR c.phone LIKE ? OR c.mac LIKE ? OR c.username LIKE ? OR c.ip LIKE ? OR c.tags LIKE ?"
            . " OR EXISTS (SELECT 1 FROM tbl_cpchat_messages ms WHERE ms.conversation_id = c.id AND ms.body LIKE ?))";
        $like = '%' . $search . '%';
        for ($i = 0; $i < 7; $i++) {
            $params[] = $like;
        }
    }
    $status = isset($filters['status']) ? $filters['status'] : '';
    if ($status === 'open' || $status === 'closed') {
        $where[] = "c.status = ?";
        $params[] = $status;
    }
    $router = isset($filters['router']) ? trim((string) $filters['router']) : '';
    if ($router !== '') {
        $where[] = "c.router = ?";
        $params[] = $router;
    }
    if (isset($filters['assigned']) && $filters['assigned'] !== '') {
        $assigned = $filters['assigned'];
        if ($assigned === 'unassigned') {
            $where[] = "(c.assigned_to IS NULL OR c.assigned_to = 0)";
        } elseif ($assigned === 'me') {
            $where[] = "c.assigned_to = ?";
            $params[] = (int) Admin::getID();
        } elseif (is_numeric($assigned)) {
            $where[] = "c.assigned_to = ?";
            $params[] = (int) $assigned;
        }
    }
    $tag = isset($filters['tag']) ? trim((string) $filters['tag']) : '';
    if ($tag !== '') {
        $where[] = "c.tags LIKE ?";
        $params[] = '%' . str_replace(['%', '_'], ['\%', '\_'], $tag) . '%';
    }
    if (!empty($filters['spam'])) {
        $where[] = "c.is_spam = 1";
    }
    $sql = "SELECT c.*, u.fullname AS assigned_fullname, u.username AS assigned_username,
            (SELECT m.body FROM tbl_cpchat_messages m WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_body,
            (SELECT m.sender FROM tbl_cpchat_messages m WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_sender,
            (SELECT COUNT(*) FROM tbl_cpchat_messages m2 WHERE m2.conversation_id = c.id) AS msg_count
        FROM tbl_cpchat_conversations c
        LEFT JOIN tbl_users u ON u.id = c.assigned_to";
    if (!empty($where)) {
        $sql .= " WHERE " . implode(' AND ', $where);
    }
    $sql .= " ORDER BY c.last_message_at DESC LIMIT " . $limit;
    $rows = ORM::for_table('tbl_cpchat_conversations')->raw_query($sql, $params)->find_array();
    return is_array($rows) ? $rows : [];
}

function cpchat_conversation_payload($c)
{
    $assignedName = '';
    if (!empty($c['assigned_to'])) {
        if (isset($c['assigned_fullname']) && $c['assigned_fullname'] !== '') {
            $assignedName = $c['assigned_fullname'];
        } elseif (!empty($c['assigned_username'])) {
            $assignedName = $c['assigned_username'];
        }
    }
    return [
        'id' => (int) $c['id'],
        'name' => $c['name'],
        'phone' => $c['phone'],
        'mac' => $c['mac'],
        'ip' => $c['ip'],
        'username' => $c['username'],
        'router' => $c['router'],
        'page' => $c['page'],
        'status' => $c['status'],
        'assigned_to' => isset($c['assigned_to']) ? (int) $c['assigned_to'] : 0,
        'assigned_name' => $assignedName,
        'tags' => cpchat_clean_tags(isset($c['tags']) ? $c['tags'] : ''),
        'close_reason' => isset($c['close_reason']) ? $c['close_reason'] : '',
        'rating' => isset($c['rating']) ? (int) $c['rating'] : 0,
        'is_spam' => isset($c['is_spam']) ? (int) $c['is_spam'] : 0,
        'first_reply_at' => isset($c['first_reply_at']) ? $c['first_reply_at'] : null,
        'unread_admin' => (int) $c['unread_admin'],
        'unread_customer' => (int) $c['unread_customer'],
        'msg_count' => isset($c['msg_count']) ? (int) $c['msg_count'] : 0,
        'last_body' => isset($c['last_body']) ? $c['last_body'] : '',
        'last_sender' => isset($c['last_sender']) ? $c['last_sender'] : '',
        'last_at' => $c['last_message_at'],
        // times are computed server-side so they always follow the PHPNuxBill
        // timezone setting and never depend on the visitor's clock
        'last_ago' => !empty($c['last_message_at']) ? Lang::timeElapsed($c['last_message_at']) : '',
        'last_dt' => !empty($c['last_message_at']) ? Lang::dateTimeFormat($c['last_message_at']) : '',
        'created_at' => $c['created_at'],
        'created_dt' => !empty($c['created_at']) ? Lang::dateTimeFormat($c['created_at']) : '',
    ];
}

function cpchat_mark_read($conversation_id, $sender, $max_id)
{
    ORM::raw_execute(
        "UPDATE tbl_cpchat_messages SET is_read = 1 WHERE conversation_id = ? AND sender = ? AND id <= ?",
        [$conversation_id, $sender, $max_id]
    );
}

function cpchat_mark_unread_reset($conversation_id, $sender)
{
    ORM::raw_execute(
        "UPDATE tbl_cpchat_messages SET is_read = 1 WHERE conversation_id = ? AND sender = ? AND is_read = 0",
        [$conversation_id, $sender]
    );
}

/* ------------------------------------------------------------------ *
 *  Assignment, tags, canned replies
 * ------------------------------------------------------------------ */

/** Admin users that can own a conversation */
function cpchat_agents_list()
{
    $rows = ORM::for_table('tbl_users')
        ->select_many('id', 'username', 'fullname', 'user_type')
        ->where('status', 'Active')
        ->order_by_desc('user_type')->order_by_asc('username')->find_array();
    $out = [];
    foreach ((array) $rows as $r) {
        $out[] = [
            'id' => (int) $r['id'],
            'name' => $r['fullname'] !== '' ? $r['fullname'] : $r['username'],
            'type' => $r['user_type'],
        ];
    }
    return $out;
}

function cpchat_agent_names()
{
    $map = [];
    foreach (cpchat_agents_list() as $a) {
        $map[$a['id']] = $a['name'];
    }
    return $map;
}

function cpchat_clean_tags($value)
{
    if (is_array($value)) {
        $parts = $value;
    } else {
        $parts = explode(',', (string) $value);
    }
    $clean = [];
    foreach ($parts as $tag) {
        $tag = mb_strtolower(trim(preg_replace('/[^\p{L}\p{N}\s_\-]/u', '', $tag)));
        $tag = preg_replace('/\s+/u', '-', $tag);
        if ($tag !== '' && mb_strlen($tag) <= 24 && !in_array($tag, $clean, true)) {
            $clean[] = $tag;
        }
        if (count($clean) >= 8) {
            break;
        }
    }
    return $clean;
}

function cpchat_tag_options()
{
    $preset = cpchat_clean_tags(explode(',', cpchat_settings()['tags']));
    $rows = ORM::for_table('tbl_cpchat_conversations')->select('tags')->where_not_equal('tags', '')->limit(500)->find_array();
    $used = [];
    foreach ((array) $rows as $r) {
        foreach (cpchat_clean_tags($r['tags']) as $tag) {
            $used[$tag] = true;
        }
    }
    return array_values(array_unique(array_merge($preset, array_keys($used))));
}

function cpchat_set_tags($id, $tags)
{
    $c = cpchat_find_conversation('', $id);
    if (!$c) {
        return null;
    }
    $c->tags = implode(',', cpchat_clean_tags($tags));
    $c->save();
    return $c;
}

function cpchat_canned_list()
{
    $rows = ORM::for_table('tbl_cpchat_canned')->order_by_asc('sort')->order_by_asc('id')->find_array();
    return is_array($rows) ? $rows : [];
}

function cpchat_canned_save($id, $title, $body)
{
    $body = cpchat_clean_text($body, 1000);
    if ($body === '') {
        return false;
    }
    $d = $id > 0 ? ORM::for_table('tbl_cpchat_canned')->find_one($id) : ORM::for_table('tbl_cpchat_canned')->create();
    if (!$d) {
        return false;
    }
    $d->title = cpchat_clean_name($title, 60);
    if ($d->title === '') {
        $d->title = mb_substr($body, 0, 30);
    }
    $d->body = $body;
    if ((int) $d->sort === 0) {
        $d->sort = (int) ORM::for_table('tbl_cpchat_canned')->count() + 1;
    }
    if (!$d->id()) {
        $d->created_at = date('Y-m-d H:i:s');
    }
    $d->save();
    return $d->id();
}

function cpchat_canned_delete($id)
{
    $d = ORM::for_table('tbl_cpchat_canned')->find_one((int) $id);
    if ($d) {
        $d->delete();
        return true;
    }
    return false;
}

/* ------------------------------------------------------------------ *
 *  Spam protection
 * ------------------------------------------------------------------ */

function cpchat_spam_log($reason, $detail = '', $ip = '', $mac = '')
{
    try {
        $l = ORM::for_table('tbl_cpchat_spamlog')->create();
        $l->ip = mb_substr((string) $ip, 0, 45);
        $l->mac = mb_substr((string) $mac, 0, 17);
        $l->reason = mb_substr((string) $reason, 0, 40);
        $l->detail = mb_substr((string) $detail, 0, 200);
        $l->created_at = date('Y-m-d H:i:s');
        $l->save();
        // keep the log small
        $old = date('Y-m-d H:i:s', time() - 30 * 86400);
        ORM::raw_execute("DELETE FROM tbl_cpchat_spamlog WHERE created_at < ?", [$old]);
    } catch (Throwable $e) {
        // logging must never break the request
    }
}

function cpchat_block($type, $value, $reason = 'auto', $hours = 24)
{
    $type = in_array($type, ['ip', 'mac', 'phone'], true) ? $type : 'ip';
    $value = trim((string) $value);
    if ($value === '') {
        return false;
    }
    $d = ORM::for_table('tbl_cpchat_blocked')->where('type', $type)->where('value', $value)->find_one();
    if (!$d) {
        $d = ORM::for_table('tbl_cpchat_blocked')->create();
        $d->type = $type;
        $d->value = mb_substr($value, 0, 60);
        $d->hits = 1;
        $d->created_at = date('Y-m-d H:i:s');
    } else {
        $d->hits = (int) $d->hits + 1;
    }
    $d->reason = mb_substr((string) $reason, 0, 160);
    $d->expires_at = date('Y-m-d H:i:s', time() + max(1, (int) $hours) * 3600);
    $d->save();
    return true;
}

function cpchat_unblock($id)
{
    $d = ORM::for_table('tbl_cpchat_blocked')->find_one((int) $id);
    if ($d) {
        $d->delete();
        return true;
    }
    return false;
}

function cpchat_blocked_list()
{
    $rows = ORM::for_table('tbl_cpchat_blocked')->order_by_desc('id')->limit(200)->find_array();
    $out = [];
    $now = date('Y-m-d H:i:s');
    foreach ((array) $rows as $r) {
        if ($r['expires_at'] !== null && $r['expires_at'] < $now) {
            continue;
        }
        $out[] = $r;
    }
    return $out;
}

/** @return string|null the blocked type when this visitor is banned */
function cpchat_is_blocked($ip, $mac = '', $phone = '')
{
    $now = date('Y-m-d H:i:s');
    $values = array_filter(['ip' => $ip, 'mac' => $mac, 'phone' => $phone]);
    if (empty($values)) {
        return null;
    }
    foreach ($values as $type => $value) {
        $d = ORM::for_table('tbl_cpchat_blocked')
            ->where('type', $type)->where('value', $value)
            ->where_raw('(expires_at IS NULL OR expires_at > ?)', [$now])->find_one();
        if ($d) {
            return $type;
        }
    }
    return null;
}

function cpchat_ip_conversation_count($ip, $seconds)
{
    if ($ip === '') {
        return 0;
    }
    return (int) ORM::for_table('tbl_cpchat_conversations')
        ->where('ip', $ip)
        ->where_gte('created_at', date('Y-m-d H:i:s', time() - $seconds))
        ->count();
}

function cpchat_ip_message_count($ip, $seconds)
{
    if ($ip === '') {
        return 0;
    }
    $sql = "SELECT COUNT(*) AS c FROM tbl_cpchat_messages m
            JOIN tbl_cpchat_conversations c ON c.id = m.conversation_id
            WHERE c.ip = ? AND m.sender = 'customer' AND m.created_at >= ?";
    $row = ORM::for_table('tbl_cpchat_messages')->raw_query($sql, [$ip, date('Y-m-d H:i:s', time() - $seconds)])->find_array();
    return isset($row[0]['c']) ? (int) $row[0]['c'] : 0;
}

/** Repeated offence from the same device/IP gets a temporary block */
function cpchat_maybe_auto_block($ip, $mac, $reason)
{
    $s = cpchat_settings();
    if (!$s['spam_auto_block']) {
        return;
    }
    $hits = (int) ORM::for_table('tbl_cpchat_spamlog')
        ->where('ip', $ip)
        ->where_gte('created_at', date('Y-m-d H:i:s', time() - 3600))
        ->count();
    if ($hits >= 5) {
        if ($ip !== '') {
            cpchat_block('ip', $ip, $reason, $s['spam_block_hours']);
        }
        if ($mac !== '') {
            cpchat_block('mac', $mac, $reason, $s['spam_block_hours']);
        }
        _log('Captive Portal Chat: blocked ' . $ip . ' (' . $reason . ')', 'System');
    }
}

/** Reject a public request and record why */
function cpchat_reject($reason, $detail = '', $message = null)
{
    $ip = cpchat_client_ip();
    $mac = isset($_REQUEST['mac']) ? cpchat_meta_value($_REQUEST['mac'], 17) : '';
    cpchat_spam_log($reason, $detail, $ip, $mac);
    cpchat_maybe_auto_block($ip, $mac, $reason);
    cpchat_error($message === null ? Lang::T('Your request was rejected, please contact support directly.') : $message);
}

function cpchat_strip_links($text)
{
    $text = preg_replace('#(https?://|www\.)\S+#i', '[link removed]', $text);
    $text = preg_replace('#\b\w+@(?:\w+\.)+\w+\b#i', '[email removed]', $text);
    return $text;
}

/** Hidden form field: humans never see it, bots fill it in */
function cpchat_honeypot_filled($b)
{
    if (!cpchat_settings()['spam_honeypot']) {
        return false;
    }
    foreach (['website', 'url', 'hp_email'] as $field) {
        if (isset($b[$field]) && trim((string) $b[$field]) !== '') {
            return true;
        }
    }
    return false;
}

function cpchat_captcha_secret()
{
    global $db_pass;
    return sha1('cpchat|' . (isset($db_pass) ? $db_pass : '') . '|' . (isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : ''));
}

/** Stateless math challenge: the answer is signed inside the token */
function cpchat_captcha_issue()
{
    $a = random_int(1, 9);
    $b = random_int(1, 9);
    $exp = time() + 900;
    $sig = substr(sha1($a . '|' . $b . '|' . $exp . '|' . cpchat_captcha_secret()), 0, 16);
    return [
        'question' => $a . ' + ' . $b . ' = ?',
        'token' => $a . '.' . $b . '.' . $exp . '.' . $sig,
    ];
}

function cpchat_captcha_check($token, $answer)
{
    $parts = explode('.', (string) $token);
    if (count($parts) !== 4) {
        return false;
    }
    list($a, $b, $exp, $sig) = $parts;
    if (!is_numeric($a) || !is_numeric($b) || !is_numeric($exp)) {
        return false;
    }
    if ((int) $exp < time()) {
        return false;
    }
    $want = substr(sha1($a . '|' . $b . '|' . $exp . '|' . cpchat_captcha_secret()), 0, 16);
    if (!hash_equals($want, (string) $sig)) {
        return false;
    }
    return (int) $answer === ((int) $a + (int) $b);
}

/** Runs a public request through the spam gauntlet, then returns the clean body */
function cpchat_guard_public($body, $ip, $mac = '', $phone = '')
{
    $s = cpchat_settings();
    $blocked = cpchat_is_blocked($ip, $mac, $phone);
    if ($blocked !== null) {
        cpchat_spam_log('blocked_' . $blocked, 'request refused', $ip, $mac);
        cpchat_error(Lang::T('Chat is not available for this connection. Please contact support.'));
    }
    if ($s['spam_strip_links']) {
        $body = cpchat_strip_links($body);
    }
    return $body;
}

/* ------------------------------------------------------------------ *
 *  Customer side endpoints (public, called from the captive portal)
 * ------------------------------------------------------------------ */

/** Safe JSON for embedding inside a <script> tag or a JS prelude */
function cpchat_js_config($data)
{
    return json_encode($data, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT);
}

function cpchatWidgetJs()
{
    $s = cpchat_settings();
    $open = cpchat_is_open();
    cpchat_output_asset(
        'widget.js',
        "window.CPCHAT_CFG = window.CPCHAT_CFG || " . cpchat_js_config([
            'enabled' => $s['enabled'],
            'title' => $s['title'],
            'welcome' => $s['welcome'],
            'agent' => $s['agent'],
            'pollOpen' => $s['poll_open'],
            'pollClosed' => $s['poll_closed'],
            'sound' => $s['sound'],
            'maxLength' => $s['max_length'],
            'version' => $s['version'],
            'honeypot' => $s['spam_honeypot'],
            'captcha' => $s['spam_captcha'],
            'open' => $open,
            'awayMessage' => $s['away_message'],
            'hours' => cpchat_hours_label(),
            'urls' => [
                'start' => cpchat_url('cpchatStart'),
                'send' => cpchat_url('cpchatSend'),
                'poll' => cpchat_url('cpchatPoll'),
                'close' => cpchat_url('cpchatClose'),
                'captcha' => cpchat_url('cpchatCaptcha'),
            ],
        ]) . ";"
    );
}

/** Math challenge for the start form, only used when spam_captcha is on */
function cpchatCaptcha()
{
    if (!cpchat_settings()['spam_captcha']) {
        cpchat_json(['success' => true, 'required' => false]);
    }
    $c = cpchat_captcha_issue();
    $c['success'] = true;
    $c['required'] = true;
    cpchat_json($c);
}

function cpchat_output_asset($filename, $prelude = '', $type = 'application/javascript')
{
    global $captivePortalChat_version;
    $path = $GLOBALS['root_path'] . 'system' . DIRECTORY_SEPARATOR . 'plugin' . DIRECTORY_SEPARATOR
        . 'ui' . DIRECTORY_SEPARATOR . 'cpchat' . DIRECTORY_SEPARATOR . $filename;
    if (!file_exists($path)) {
        if (!headers_sent()) {
            header('Content-Type: ' . $type . '; charset=utf-8');
            header('Access-Control-Allow-Origin: *');
        }
        echo ($type === 'text/css') ? '/* Captive Portal Chat: ' . $filename . ' is missing */' : '/* Captive Portal Chat: ' . $filename . ' is missing */';
        exit;
    }
    $body = file_get_contents($path);
    if ($prelude !== '') {
        $body = $prelude . "\n" . $body;
    }
    if (!headers_sent()) {
        header('Content-Type: ' . $type . '; charset=utf-8');
        header('Access-Control-Allow-Origin: *');
        header('Cache-Control: public, max-age=120');
        header('X-Robots-Tag: noindex');
    }
    echo $body;
    exit;
}

function cpchatStart()
{
    $s = cpchat_settings();
    if (!$s['enabled']) {
        cpchat_error('Chat is disabled');
    }
    if (!cpchat_ready()) {
        cpchat_error('Chat storage is not ready');
    }
    $b = cpchat_post_body();
    $token = isset($b['token']) ? preg_replace('/[^a-f0-9]/', '', strtolower($b['token'])) : '';
    $name = cpchat_clean_name(isset($b['name']) ? $b['name'] : '', 60);
    $phone = cpchat_meta_value(isset($b['phone']) ? $b['phone'] : '', 24);
    $mac = cpchat_meta_value(isset($b['mac']) ? $b['mac'] : '', 17);
    $ip = filter_var(isset($b['ip']) ? $b['ip'] : '', FILTER_VALIDATE_IP) ? $b['ip'] : cpchat_client_ip();
    $username = cpchat_meta_value(isset($b['username']) ? $b['username'] : '', 60);
    $router = cpchat_meta_value(isset($b['router']) ? $b['router'] : '', 60);
    $page = cpchat_meta_value(isset($b['page']) ? $b['page'] : '', 15);

    if ($name === '' || mb_strlen($name) < 2) {
        cpchat_error('Please enter your name');
    }
    $digits = preg_replace('/\D/', '', $phone);
    if (strlen($digits) < 6 || strlen($digits) > 15) {
        cpchat_error('Please enter a valid phone number');
    }

    /* ---- spam gauntlet ---- */
    if (cpchat_honeypot_filled($b)) {
        cpchat_reject('honeypot', 'start', Lang::T('Please enter your name and phone number'));
    }
    if ($s['spam_captcha']) {
        $answer = isset($b['captcha']) ? trim((string) $b['captcha']) : '';
        $challenge = isset($b['captcha_token']) ? trim((string) $b['captcha_token']) : '';
        if (!cpchat_captcha_check($challenge, $answer)) {
            cpchat_reject('captcha', 'start', Lang::T('Wrong answer, please try again'));
        }
    }
    $blocked = cpchat_is_blocked($ip, $mac, $phone);
    if ($blocked !== null) {
        cpchat_spam_log('blocked_' . $blocked, 'start refused', $ip, $mac);
        cpchat_error(Lang::T('Chat is not available for this connection. Please contact support.'));
    }

    $conversation = $token !== '' ? cpchat_find_conversation($token) : null;

    // resume the same open chat for the same device + phone
    if (!$conversation) {
        $q = ORM::for_table('tbl_cpchat_conversations')
            ->where('phone', $phone)->where('status', 'open');
        if ($mac !== '') {
            $q->where('mac', $mac);
        }
        $conversation = $q->order_by_desc('id')->find_one();
    }

    if (!$conversation) {
        // abuse guard: chats started from this connection
        if ($s['spam_cooldown'] > 0 && cpchat_ip_conversation_count($ip, $s['spam_cooldown']) > 0) {
            cpchat_reject('cooldown', 'start', Lang::T('Please wait a moment before starting a new chat'));
        }
        if (cpchat_ip_conversation_count($ip, 3600) >= $s['spam_max_chats']) {
            cpchat_reject('too_many_chats', 'start', Lang::T('Too many chats started from this connection. Try again later.'));
        }
        $conversation = ORM::for_table('tbl_cpchat_conversations')->create();
        $conversation->token = cpchat_new_token();
        $conversation->status = 'open';
        $conversation->unread_admin = 0;
        $conversation->unread_customer = 0;
        $conversation->last_message_id = 0;
        $conversation->customer_seen_id = 0;
        $conversation->created_at = date('Y-m-d H:i:s');
    }

    $conversation->name = $name;
    $conversation->phone = $phone;
    if ($mac !== '') {
        $conversation->mac = $mac;
    }
    if ($ip !== '') {
        $conversation->ip = $ip;
    }
    if ($username !== '') {
        $conversation->username = $username;
    }
    if ($router !== '') {
        $conversation->router = $router;
    }
    if ($page !== '') {
        $conversation->page = $page;
    }
    $conversation->updated_at = date('Y-m-d H:i:s');
    $conversation->save();

    $open = cpchat_is_open();
    if ((int) $conversation->last_message_id === 0) {
        cpchat_add_message($conversation->id(), 'system', $s['welcome']);
        if (!$open) {
            cpchat_add_message($conversation->id(), 'system', $s['away_message'] . ' (' . cpchat_hours_label() . ')');
        }
    }

    $rows = ORM::for_table('tbl_cpchat_messages')
        ->where('conversation_id', $conversation->id())
        ->order_by_desc('id')->limit(50)->find_array();
    $messages = array_reverse(cpchat_map_messages($rows));
    $lastId = empty($messages) ? 0 : $messages[count($messages) - 1]['id'];

    cpchat_json([
        'success' => true,
        'token' => $conversation->token,
        'status' => $conversation->status,
        'last_id' => $lastId,
        'messages' => $messages,
        'config' => [
            'title' => $s['title'],
            'agent' => $s['agent'],
            'pollOpen' => $s['poll_open'],
            'pollClosed' => $s['poll_closed'],
            'maxLength' => $s['max_length'],
            'sound' => $s['sound'],
            'open' => $open,
            'hours' => cpchat_hours_label(),
            'awayMessage' => $s['away_message'],
        ],
    ]);
}

function cpchat_map_messages($rows)
{
    $out = [];
    if (!is_array($rows)) {
        return $out;
    }
    foreach ($rows as $m) {
        $out[] = cpchat_message_row($m);
    }
    return $out;
}

function cpchatSend()
{
    $s = cpchat_settings();
    if (!$s['enabled'] || !cpchat_ready()) {
        cpchat_error('Chat is unavailable');
    }
    $b = cpchat_post_body();
    $token = isset($b['token']) ? preg_replace('/[^a-f0-9]/', '', strtolower($b['token'])) : '';
    $ref = isset($b['ref']) ? preg_replace('/[^A-Za-z0-9\-]/', '', $b['ref']) : '';
    $body = cpchat_clean_text(isset($b['body']) ? $b['body'] : '', $s['max_length']);
    if ($token === '' || $body === '') {
        cpchat_error('Nothing to send');
    }
    $conversation = cpchat_find_conversation($token);
    if (!$conversation) {
        cpchat_error('Chat not found, please start a new chat');
    }
    if ($conversation->status !== 'open') {
        cpchat_error('This chat is closed, please start a new chat');
    }
    /* ---- spam gauntlet ---- */
    if (cpchat_honeypot_filled($b)) {
        cpchat_reject('honeypot', 'send', Lang::T('Nothing to send'));
    }
    $ip = $conversation->ip !== '' ? $conversation->ip : cpchat_client_ip();
    $blocked = cpchat_is_blocked($ip, $conversation->mac, $conversation->phone);
    if ($blocked !== null) {
        cpchat_spam_log('blocked_' . $blocked, 'send refused', $ip, $conversation->mac);
        cpchat_error(Lang::T('Chat is not available for this connection. Please contact support.'));
    }
    $stripped = false;
    if ($s['spam_strip_links']) {
        $clean = cpchat_strip_links($body);
        if ($clean !== $body) {
            cpchat_spam_log('link_stripped', mb_substr($body, 0, 120), $ip, $conversation->mac);
            $body = $clean;
            $stripped = true;
        }
    }
    // rate limit per conversation
    $recent = ORM::for_table('tbl_cpchat_messages')
        ->where('conversation_id', $conversation->id())
        ->where('sender', 'customer')
        ->where_gte('created_at', date('Y-m-d H:i:s', time() - 60))
        ->count();
    if ($recent > 20) {
        cpchat_reject('chat_flood', 'send', Lang::T('You are sending too fast, please wait a moment'));
    }
    // rate limit per connection, across every chat of this customer
    if (cpchat_ip_message_count($ip, 300) >= $s['spam_max_msgs']) {
        cpchat_reject('ip_flood', 'send', Lang::T('You are sending too fast, please wait a moment'));
    }
    if ($body === '') {
        cpchat_error('Nothing to send');
    }
    $res = cpchat_add_message($conversation->id(), 'customer', $body, $ref, 0, $conversation->name);
    $conversation->unread_customer = 0;
    $conversation->save();

    cpchat_json(['success' => true, 'id' => $res['id'], 'at' => $res['created_at'], 'replay' => $res['replay'], 'stripped' => $stripped]);
}

function cpchatPoll()
{
    if (!cpchat_ready()) {
        cpchat_error('Chat is unavailable');
    }
    $b = cpchat_post_body();
    $token = isset($b['token']) ? preg_replace('/[^a-f0-9]/', '', strtolower($b['token'])) : '';
    $since = isset($b['since']) ? (int) $b['since'] : 0;
    if ($token === '') {
        cpchat_error('Chat not found');
    }
    $conversation = cpchat_find_conversation($token);
    if (!$conversation) {
        cpchat_error('Chat not found, please start a new chat');
    }
    // keep device / account details fresh: after login status.html exposes $(username)
    $username = cpchat_meta_value(isset($b['username']) ? $b['username'] : '', 60);
    $mac = cpchat_meta_value(isset($b['mac']) ? $b['mac'] : '', 17);
    $page = cpchat_meta_value(isset($b['page']) ? $b['page'] : '', 15);
    $touch = false;
    if ($username !== '' && $conversation->username !== $username) {
        $conversation->username = $username;
        $touch = true;
    }
    if ($mac !== '' && $conversation->mac !== $mac) {
        $conversation->mac = $mac;
        $touch = true;
    }
    if ($page !== '' && $conversation->page !== $page) {
        $conversation->page = $page;
        $touch = true;
    }
    $rows = ORM::for_table('tbl_cpchat_messages')
        ->where('conversation_id', $conversation->id())
        ->where_gt('id', $since)
        ->order_by_asc('id')->limit(100)->find_array();
    $messages = cpchat_map_messages($rows);

    // customer has seen the replies
    $maxSeen = 0;
    foreach ($messages as $m) {
        if ($m['sender'] !== 'customer' && $m['id'] > $maxSeen) {
            $maxSeen = $m['id'];
        }
    }
    $changed = false;
    if ($maxSeen > 0) {
        cpchat_mark_read($conversation->id(), 'admin', $maxSeen);
        if ((int) $conversation->unread_customer !== 0) {
            $conversation->unread_customer = 0;
            $changed = true;
        }
        if ($maxSeen > (int) $conversation->customer_seen_id) {
            $conversation->customer_seen_id = $maxSeen;
            $changed = true;
        }
    }
    if ($changed || $touch) {
        $conversation->save();
    }

    cpchat_json([
        'success' => true,
        'status' => $conversation->status,
        'messages' => $messages,
        'open' => cpchat_is_open(),
        'last_id' => empty($messages) ? $since : $messages[count($messages) - 1]['id'],
    ]);
}

function cpchatClose()
{
    if (!cpchat_ready()) {
        cpchat_error('Chat is unavailable');
    }
    $b = cpchat_post_body();
    $token = isset($b['token']) ? preg_replace('/[^a-f0-9]/', '', strtolower($b['token'])) : '';
    $conversation = cpchat_find_conversation($token);
    if (!$conversation) {
        cpchat_error('Chat not found');
    }
    $conversation->status = 'closed';
    $conversation->updated_at = date('Y-m-d H:i:s');
    $conversation->save();
    cpchat_add_message($conversation->id(), 'system', 'Chat closed by customer.');
    cpchat_json(['success' => true]);
}

/* ------------------------------------------------------------------ *
 *  Admin pages
 * ------------------------------------------------------------------ */

/** Guard + shared assigns for the three admin pages. Returns the admin row. */
function cpchat_page($title)
{
    global $ui, $captivePortalChat_version;
    _admin();
    $ui->assign('_title', $title);
    $admin = cpchat_admin();
    $ui->assign('_admin', $admin);
    if (!cpchat_can_manage($admin)) {
        _alert(Lang::T('You do not have permission to access this page'), 'danger', "dashboard");
        exit;
    }
    $install = cpchat_install();
    $ui->assign('install_error', ($install === true) ? '' : $install);
    $ui->assign('cpchat_version', $captivePortalChat_version);
    $ui->assign('navbar_state', cpchatnavbar_state());
    $ui->assign('s', cpchat_settings());
    $ui->assign('stats', cpchat_stats());
    $ui->assign('open_now', cpchat_is_open());
    $ui->assign('hours_label', cpchat_hours_label());
    $ui->assign('xfooter', cpchat_footer_credit());
    return $admin;
}

/** Dashboard: stats cards, activity chart, latest chats, per-router and per-agent breakdown */
function captivePortalChat()
{
    global $ui;
    cpchat_page(Lang::T('Captive Portal Chat'));
    $series = cpchat_stats_series(14);
    $chartEmpty = true;
    $chart = [];
    foreach ($series as $point) {
        $chart[] = [
            'label' => $point['label'],
            'chats' => $point['chats'],
            'messages' => $point['messages'],
            'closed' => $point['closed'],
            'blocked' => $point['blocked'],
        ];
        if ($point['chats'] > 0 || $point['messages'] > 0) {
            $chartEmpty = false;
        }
    }
    $ui->assign('chart_json', json_encode($chart));
    $ui->assign('chart_empty', $chartEmpty);
    $ui->assign('latest', array_map('cpchat_conversation_payload', cpchat_conversation_query([], 10)));
    $ui->assign('routers', cpchat_router_stats());
    $ui->assign('workload', cpchat_agent_workload());
    $ui->assign('spam', cpchat_spam_stats());
    $ui->assign('spamlog', cpchat_spamlog_list(12));
    $ui->assign('xheader', cpchat_page_assets('dashboard'));
    $ui->display('cpchat/dashboard.tpl');
}

/** Two-column chat workbench */
function captivePortalChatInbox()
{
    global $ui;
    $admin = cpchat_page(Lang::T('Chat Inbox'));
    $filters = cpchat_filters_from_request();
    $activeId = (int) _get('id');
    $thread = [];
    $active = null;
    if ($activeId > 0) {
        $c = cpchat_find_conversation('', $activeId);
        if ($c) {
            $row = $c->as_array();
            $thread = cpchat_thread($activeId, 300);
            cpchat_mark_unread_reset($activeId, 'customer');
            if ((int) $c->unread_admin !== 0) {
                $c->unread_admin = 0;
                $c->save();
                $row['unread_admin'] = 0;
            }
            $active = $row;
        }
    }
    $ui->assign('filters', $filters);
    $ui->assign('active_id', $activeId);
    $ui->assign('active', $active ? cpchat_conversation_payload($active) : null);
    $ui->assign('thread', $thread);
    $ui->assign('thread_last_id', empty($thread) ? 0 : (int) $thread[count($thread) - 1]['id']);
    $agents = cpchat_agents_list();
    $canned = cpchat_canned_list();
    $tagOptions = cpchat_tag_options();
    $closeReasons = cpchat_close_reasons();
    $ui->assign('conversations', array_map('cpchat_conversation_payload', cpchat_conversation_query($filters, 200)));
    $ui->assign('agents', $agents);
    $ui->assign('me_id', (int) $admin['id']);
    $ui->assign('tagOptions', $tagOptions);
    $ui->assign('canned', $canned);
    $ui->assign('routers', cpchat_routers_list());
    $ui->assign('closeReasons', $closeReasons);
    $ui->assign('xheader', cpchat_page_assets('inbox', [
        'agents' => $agents,
        'canned' => $canned,
        'tags' => $tagOptions,
        'closeReasons' => $closeReasons,
        'me_id' => (int) $admin['id'],
    ]));
    $ui->display('cpchat/inbox.tpl');
}

function cpchat_close_reasons()
{
    $out = [];
    foreach (explode(',', cpchat_settings()['close_reasons']) as $reason) {
        $reason = trim($reason);
        if ($reason !== '') {
            $out[] = $reason;
        }
    }
    return $out;
}

function captivePortalChatSettings()
{
    global $ui, $_app_stage, $captivePortalChat_version;
    $admin = cpchat_page(Lang::T('Captive Portal Chat Settings'));

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if ($_app_stage == 'Demo') {
            r2(cpchat_url('captivePortalChatSettings'), 'e', Lang::T('You cannot perform this action in Demo mode'));
        }
        $action = _post('action');
        if ($action === 'navbar_on') {
            $r = cpchatnavbar_install();
            r2(cpchat_url('captivePortalChatSettings'), ($r === true ? 's' : 'e'), $r === true ? Lang::T('Navbar notification installed') : $r);
        }
        if ($action === 'navbar_off') {
            $r = cpchatnavbar_remove();
            r2(cpchat_url('captivePortalChatSettings'), ($r === true ? 's' : 'e'), $r === true ? Lang::T('Navbar notification removed') : $r);
        }
        if ($action === 'canned_add') {
            $id = (int) _post('canned_id', 0);
            $ok = cpchat_canned_save($id, _post('canned_title', ''), _post('canned_body', ''));
            r2(cpchat_url('captivePortalChatSettings'), ($ok ? 's' : 'e'), $ok ? Lang::T('Saved') : Lang::T('Nothing saved'));
        }
        if ($action === 'canned_delete') {
            cpchat_canned_delete((int) _post('canned_id', 0));
            r2(cpchat_url('captivePortalChatSettings'), 's', Lang::T('Deleted'));
        }
        if ($action === 'block_add') {
            $type = _post('block_type', 'ip');
            $value = cpchat_meta_value(_post('block_value', ''), 60);
            if ($value !== '') {
                cpchat_block($type, $value, 'manual', max(1, (int) _post('block_hours', 24)));
                r2(cpchat_url('captivePortalChatSettings'), 's', Lang::T('Blocked'));
            }
            r2(cpchat_url('captivePortalChatSettings'), 'e', Lang::T('Nothing to block'));
        }
        if ($action === 'block_delete') {
            cpchat_unblock((int) _post('block_id', 0));
            r2(cpchat_url('captivePortalChatSettings'), 's', Lang::T('Unblocked'));
        }
        if ($action === 'spam_clear') {
            ORM::raw_execute("DELETE FROM tbl_cpchat_spamlog WHERE created_at < ?", [date('Y-m-d H:i:s', time() - 86400)]);
            r2(cpchat_url('captivePortalChatSettings'), 's', Lang::T('Old spam entries cleared'));
        }
        // every settings tab posts its own group, so untouched groups are never wiped
        $form = _post('cpchat_form', 'general');
        if ($form === 'general') {
            cpchat_save_setting('cpchat_enabled', _post('cpchat_enabled') === 'yes' ? 'yes' : 'no');
            cpchat_save_setting('cpchat_sound', _post('cpchat_sound') === 'yes' ? 'yes' : 'no');
            cpchat_save_setting('cpchat_title', cpchat_clean_text(_post('cpchat_title'), 80));
            cpchat_save_setting('cpchat_welcome', cpchat_clean_text(_post('cpchat_welcome'), 300));
            cpchat_save_setting('cpchat_agent', cpchat_clean_text(_post('cpchat_agent'), 60));
            cpchat_save_setting('cpchat_poll_open', max(2, (int) _post('cpchat_poll_open', 5)));
            cpchat_save_setting('cpchat_poll_closed', max(10, (int) _post('cpchat_poll_closed', 20)));
            cpchat_save_setting('cpchat_poll_admin', max(5, (int) _post('cpchat_poll_admin', 15)));
            cpchat_save_setting('cpchat_max_length', min(2000, max(100, (int) _post('cpchat_max_length', 1000))));
        } elseif ($form === 'hours') {
            cpchat_save_setting('cpchat_hours_enabled', _post('cpchat_hours_enabled') === 'yes' ? 'yes' : 'no');
            cpchat_save_setting('cpchat_hours_start', cpchat_time_value(_post('cpchat_hours_start'), '08:00'));
            cpchat_save_setting('cpchat_hours_end', cpchat_time_value(_post('cpchat_hours_end'), '20:00'));
            cpchat_save_setting('cpchat_hours_days', cpchat_days_value(isset($_POST['cpchat_hours_days']) ? $_POST['cpchat_hours_days'] : []));
            cpchat_save_setting('cpchat_away_message', cpchat_clean_text(_post('cpchat_away_message'), 300));
        } elseif ($form === 'moderation') {
            cpchat_save_setting('cpchat_tags', implode(',', cpchat_clean_tags(_post('cpchat_tags'))));
            cpchat_save_setting('cpchat_close_reasons', cpchat_clean_text(_post('cpchat_close_reasons'), 300));
        } elseif ($form === 'spam') {
            cpchat_save_setting('cpchat_spam_honeypot', _post('cpchat_spam_honeypot') === 'yes' ? 'yes' : 'no');
            cpchat_save_setting('cpchat_spam_captcha', _post('cpchat_spam_captcha') === 'yes' ? 'yes' : 'no');
            cpchat_save_setting('cpchat_spam_strip_links', _post('cpchat_spam_strip_links') === 'yes' ? 'yes' : 'no');
            cpchat_save_setting('cpchat_spam_auto_block', _post('cpchat_spam_auto_block') === 'yes' ? 'yes' : 'no');
            cpchat_save_setting('cpchat_spam_max_chats', max(1, (int) _post('cpchat_spam_max_chats', 5)));
            cpchat_save_setting('cpchat_spam_max_msgs', max(5, (int) _post('cpchat_spam_max_msgs', 40)));
            cpchat_save_setting('cpchat_spam_cooldown', max(0, (int) _post('cpchat_spam_cooldown', 15)));
            cpchat_save_setting('cpchat_spam_block_hours', max(1, (int) _post('cpchat_spam_block_hours', 24)));
        }
        _log('[' . $admin['username'] . ']: Captive Portal Chat settings saved', $admin['user_type'], $admin['id']);
        r2(cpchat_url('captivePortalChatSettings'), 's', Lang::T('Settings Saved Successfully'));
    }

    $s = cpchat_settings();
    $ui->assign('hoursOn', array_flip(array_filter(array_map('intval', explode(',', $s['hours_days'])))));
    $ui->assign('canned', cpchat_canned_list());
    $ui->assign('blocked', cpchat_blocked_list());
    $ui->assign('spamlog', cpchat_spamlog_list(20));
    $ui->assign('tagOptions', cpchat_tag_options());
    $ui->assign('closeReasons', cpchat_close_reasons());
    $ui->assign('routers', cpchat_routers_list());
    $ui->assign('snippet_login', cpchat_snippet('login'));
    $ui->assign('snippet_logout', cpchat_snippet('logout'));
    $ui->assign('snippet_status', cpchat_snippet('status'));
    $ui->assign('xheader', cpchat_page_assets(''));
    $ui->display('cpchat/settings.tpl');
}

function cpchat_time_value($value, $default)
{
    return preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', (string) $value) ? $value : $default;
}

function cpchat_days_value($value)
{
    $days = array_filter(array_map('intval', (array) $value), function ($d) {
        return $d >= 1 && $d <= 7;
    });
    sort($days);
    return implode(',', array_unique($days));
}

/** Credit line injected into the admin footer (reuses the theme #version slot) */
function cpchat_footer_credit()
{
    $version = htmlspecialchars($GLOBALS['captivePortalChat_version'], ENT_QUOTES, 'UTF-8');
    return '<script>
document.addEventListener("DOMContentLoaded", function () {
    var el = document.getElementById("version");
    if (el) {
        el.innerHTML = "Captive Portal Chat v' . $version . ' | <a href=\"https://linktr.ee/systik\" target=\"_blank\" rel=\"noopener\" onclick=\"event.stopPropagation();\">Mahmud</a>";
    }
});
</script>';
}

function cpchat_page_assets($page, $data = [])
{
    $css = '<link rel="stylesheet" href="' . cpchat_url('cpchatStyleJs', ['v' => $GLOBALS['captivePortalChat_version']]) . '">';
    if ($page === 'dashboard') {
        $js = '<script src="https://cdn.jsdelivr.net/npm/apexcharts@3.45.2/dist/apexcharts.min.js"></script>';
    } else {
        $js = '';
    }
    // boot.php only adds .active to our sidebar entry on the dashboard route;
    // the other pages highlight it here so core files stay untouched
    $js .= '<script>(function(){if(!/[?&]_route=plugin\/captivePortalChat/.test(location.search)){return;}'
        . 'var links=document.querySelectorAll(".sidebar-menu a[href*=\"plugin/captivePortalChat\"]");if(!links.length){return;}'
        . 'var cur=document.querySelectorAll(".sidebar-menu li.active");for(var i=0;i<cur.length;i++){cur[i].classList.remove("active");}'
        . 'for(var j=0;j<links.length;j++){var li=links[j].parentNode;if(li&&li.tagName==="LI"&&!/active/.test(li.className)){li.className+=" active";}}})();</script>';
    if ($page === 'inbox') {
        $s = cpchat_settings();
        $config = array_merge([
            'urls' => [
                'threads' => cpchat_url('cpchatAdminThreads'),
                'thread' => cpchat_url('cpchatAdminThread'),
                'send' => cpchat_url('cpchatAdminSend'),
                'status' => cpchat_url('cpchatAdminStatus'),
                'close' => cpchat_url('cpchatAdminClose'),
                'poll' => cpchat_url('cpchatAdminPoll'),
                'assign' => cpchat_url('cpchatAdminAssign'),
                'tags' => cpchat_url('cpchatAdminTags'),
                'spam' => cpchat_url('cpchatAdminSpam'),
                'block' => cpchat_url('cpchatAdminBlock'),
                'settings' => cpchat_url('captivePortalChatSettings'),
                'csv' => cpchat_url('cpchatExportCsv'),
                'pdf' => cpchat_url('cpchatExportPdf'),
            ],
            'poll' => $s['poll_admin'],
            'sound' => $s['sound'],
            'max_length' => $s['max_length'],
            'open' => cpchat_is_open(),
            'hours' => cpchat_hours_label(),
            'navbar' => cpchatnavbar_state()['status'],
        ], $data);
        $js = '<script>window.CPCHAT_ADMIN = ' . cpchat_js_config($config) . ';</script>';
    }
    // no Font Awesome CDN here on purpose: the admin theme ships FA 4.3 and
    // loading FA 5 over it breaks every `fa fa-*` icon, including our navbar bell.
    return $css . $js;
}

function cpchatStyleJs()
{
    cpchat_output_asset('cpchat.css', '', 'text/css');
}

function cpchatNavbarJs()
{
    if (!Admin::getID()) {
        header('Content-Type: application/javascript; charset=utf-8');
        echo '/* Captive Portal Chat: admin session not found */';
        exit;
    }
    $admin = cpchat_admin();
    if (!cpchat_can_manage($admin)) {
        header('Content-Type: application/javascript; charset=utf-8');
        echo '/* Captive Portal Chat: no permission */';
        exit;
    }
    $s = cpchat_settings();
    $config = [
        'enabled' => $s['enabled'],
        'poll' => $s['poll_admin'],
        'sound' => $s['sound'],
        'inbox' => cpchat_url('captivePortalChatInbox'),
        'urls' => [
            'poll' => cpchat_url('cpchatAdminPoll'),
            'count' => cpchat_url('cpchatAdminCount'),
        ],
    ];
    cpchat_output_asset('navbar.js', 'window.CPCHAT_NAVBAR = window.CPCHAT_NAVBAR || ' . cpchat_js_config($config) . ';');
}

function cpchat_snippet($page)
{
    $src = cpchat_url('cpchatWidgetJs', ['v' => $GLOBALS['captivePortalChat_version']]);
    return "<!-- Captive Portal Chat :: begin -->\n"
        . "<script>\n"
        . "window.CPCHAT_PAGE = {\n"
        . "  mac: '$(mac)',\n"
        . "  ip: '$(ip)',\n"
        . "  username: '$(username)',\n"
        . "  router: '$(hostname)',\n"
        . "  page: '" . $page . "'\n"
        . "};\n"
        . "</script>\n"
        . "<script src=\"" . $src . "\"></script>\n"
        . "<!-- Captive Portal Chat :: end -->";
}

/* ------------------------------------------------------------------ *
 *  Admin JSON endpoints
 * ------------------------------------------------------------------ */

function cpchat_require_admin()
{
    if (!Admin::getID()) {
        cpchat_error('Unauthorized', 401);
    }
    $admin = cpchat_admin();
    if (!cpchat_can_manage($admin)) {
        cpchat_error('No permission', 403);
    }
    if (!cpchat_ready()) {
        cpchat_error('Chat storage is not ready');
    }
    return $admin;
}

function cpchatAdminThreads()
{
    cpchat_require_admin();
    $status = _get('status', '');
    $assigned = _get('assigned', '');
    $filters = [
        'q' => cpchat_clean_text(_get('q', ''), 60),
        'status' => ($status === 'open' || $status === 'closed') ? $status : '',
        'router' => cpchat_meta_value(_get('router', ''), 60),
        'assigned' => ($assigned === 'me' || $assigned === 'unassigned' || is_numeric($assigned)) ? $assigned : '',
        'tag' => cpchat_clean_text(_get('tag', ''), 24),
        'spam' => _get('spam', '') === '1',
    ];
    $rows = cpchat_conversation_query($filters, 200);
    $out = [];
    foreach ($rows as $c) {
        $out[] = cpchat_conversation_payload($c);
    }
    cpchat_json(['success' => true, 'conversations' => $out, 'at' => date('H:i:s')]);
}

function cpchatAdminThread()
{
    cpchat_require_admin();
    $id = (int) _get('id');
    $since = (int) _get('since');
    $conversation = cpchat_find_conversation('', $id);
    if (!$conversation) {
        cpchat_error('Conversation not found');
    }
    $rows = ORM::for_table('tbl_cpchat_messages')
        ->where('conversation_id', $id)
        ->where_gt('id', $since)
        ->order_by_asc('id')->limit(300)->find_array();
    $messages = cpchat_map_messages($rows);
    $lastId = empty($messages) ? $since : (int) $messages[count($messages) - 1]['id'];
    if ((int) $conversation->last_message_id > $lastId) {
        $lastId = (int) $conversation->last_message_id;
    }
    // admin has read everything inside this conversation
    cpchat_mark_unread_reset($id, 'customer');
    if ((int) $conversation->unread_admin !== 0) {
        $conversation->unread_admin = 0;
        $conversation->save();
    }
    $fresh = ORM::for_table('tbl_cpchat_conversations')->find_one($id);
    cpchat_json([
        'success' => true,
        'conversation' => cpchat_conversation_payload($fresh->as_array()),
        'messages' => $messages,
        'last_id' => $lastId,
    ]);
}

function cpchatAdminSend()
{
    $admin = cpchat_require_admin();
    $b = cpchat_post_body();
    $id = isset($b['id']) ? (int) $b['id'] : 0;
    $body = cpchat_clean_text(isset($b['body']) ? $b['body'] : '', cpchat_settings()['max_length']);
    $conversation = cpchat_find_conversation('', $id);
    if (!$conversation) {
        cpchat_error('Conversation not found');
    }
    if ($body === '') {
        cpchat_error('Nothing to send');
    }
    $name = $admin['fullname'] !== '' ? $admin['fullname'] : $admin['username'];
    $res = cpchat_add_message($id, 'admin', $body, '', (int) $admin['id'], $name);
    // whoever answers a loose chat quietly becomes its owner
    if ((int) $conversation->assigned_to === 0) {
        $conversation->assigned_to = (int) $admin['id'];
        $conversation->assigned_at = date('Y-m-d H:i:s');
    }
    $conversation->unread_customer = 1;
    $conversation->save();
    cpchat_json(['success' => true, 'id' => $res['id'], 'at' => $res['created_at'], 'assigned_to' => (int) $conversation->assigned_to]);
}

function cpchatAdminStatus()
{
    $admin = cpchat_require_admin();
    $b = cpchat_post_body();
    $id = isset($b['id']) ? (int) $b['id'] : 0;
    $status = (isset($b['status']) && $b['status'] === 'open') ? 'open' : 'closed';
    $conversation = cpchat_find_conversation('', $id);
    if (!$conversation) {
        cpchat_error('Conversation not found');
    }
    $conversation->status = $status;
    $conversation->updated_at = date('Y-m-d H:i:s');
    $conversation->save();
    cpchat_add_message($id, 'system', Lang::T('Chat') . ' ' . $status . ' by ' . $admin['username']);
    cpchat_json(['success' => true, 'status' => $status]);
}

/** Close a chat with a reason */
function cpchatAdminClose()
{
    $admin = cpchat_require_admin();
    $b = cpchat_post_body();
    $id = isset($b['id']) ? (int) $b['id'] : 0;
    $conversation = cpchat_find_conversation('', $id);
    if (!$conversation) {
        cpchat_error('Conversation not found');
    }
    $reason = cpchat_clean_text(isset($b['reason']) ? $b['reason'] : '', 60);
    $note = cpchat_clean_text(isset($b['note']) ? $b['note'] : '', 500);
    $conversation->status = 'closed';
    $conversation->close_reason = $reason;
    $conversation->updated_at = date('Y-m-d H:i:s');
    $conversation->save();
    if ($note !== '') {
        $name = $admin['fullname'] !== '' ? $admin['fullname'] : $admin['username'];
        cpchat_add_message($id, 'admin', $note, '', (int) $admin['id'], $name);
    }
    $label = $reason !== '' ? ' (' . $reason . ')' : '';
    cpchat_add_message($id, 'system', Lang::T('Chat closed by ') . $admin['username'] . $label);
    cpchat_json(['success' => true, 'status' => 'closed', 'close_reason' => $reason]);
}

/** Assign / unassign an agent */
function cpchatAdminAssign()
{
    $admin = cpchat_require_admin();
    $b = cpchat_post_body();
    $id = isset($b['id']) ? (int) $b['id'] : 0;
    $conversation = cpchat_find_conversation('', $id);
    if (!$conversation) {
        cpchat_error('Conversation not found');
    }
    $target = isset($b['assigned_to']) ? $b['assigned_to'] : '0';
    if ($target === 'me') {
        $target = (int) $admin['id'];
    }
    $target = (int) $target;
    if ($target > 0) {
        $agent = ORM::for_table('tbl_users')->select_many('id', 'fullname', 'username')->find_one($target);
        if (!$agent) {
            cpchat_error('Agent not found');
        }
    }
    $conversation->assigned_to = $target;
    $conversation->assigned_at = ($target > 0) ? date('Y-m-d H:i:s') : null;
    $conversation->updated_at = date('Y-m-d H:i:s');
    $conversation->save();
    $names = cpchat_agent_names();
    if ($target > 0) {
        $who = isset($names[$target]) ? $names[$target] : ('#' . $target);
        cpchat_add_message($id, 'system', Lang::T('Assigned to ') . $who);
    } else {
        cpchat_add_message($id, 'system', Lang::T('Assignment cleared') . ' (' . $admin['username'] . ')');
    }
    cpchat_json(['success' => true, 'assigned_to' => $target, 'assigned_name' => ($target > 0 && isset($names[$target])) ? $names[$target] : '']);
}

/** Replace the tag list of a conversation */
function cpchatAdminTags()
{
    cpchat_require_admin();
    $b = cpchat_post_body();
    $id = isset($b['id']) ? (int) $b['id'] : 0;
    $tags = '';
    if (isset($b['tags'])) {
        $tags = is_array($b['tags']) ? implode(',', $b['tags']) : (string) $b['tags'];
    }
    $c = cpchat_set_tags($id, $tags);
    if (!$c) {
        cpchat_error('Conversation not found');
    }
    cpchat_json(['success' => true, 'tags' => cpchat_clean_tags($c->tags)]);
}

/** Mark/unmark as spam and optionally block the visitor */
function cpchatAdminSpam()
{
    $admin = cpchat_require_admin();
    $b = cpchat_post_body();
    $id = isset($b['id']) ? (int) $b['id'] : 0;
    $flag = isset($b['spam']) ? (int) $b['spam'] : 0;
    $doBlock = isset($b['block']) && $b['block'] === 'yes';
    $conversation = cpchat_find_conversation('', $id);
    if (!$conversation) {
        cpchat_error('Conversation not found');
    }
    $s = cpchat_settings();
    $conversation->is_spam = $flag ? 1 : 0;
    if ($flag) {
        $conversation->status = 'closed';
        $conversation->close_reason = 'Spam';
    }
    $conversation->updated_at = date('Y-m-d H:i:s');
    $conversation->save();
    $blocked = [];
    if ($flag) {
        cpchat_spam_log('marked_spam', 'chat #' . $id . ' by ' . $admin['username'], $conversation->ip, $conversation->mac);
        if ($doBlock) {
            foreach (['ip' => $conversation->ip, 'mac' => $conversation->mac, 'phone' => $conversation->phone] as $type => $value) {
                if ($value !== '' && cpchat_block($type, $value, 'marked spam chat #' . $id, $s['spam_block_hours'])) {
                    $blocked[] = $type;
                }
            }
        }
    }
    cpchat_json(['success' => true, 'is_spam' => (int) $conversation->is_spam, 'blocked' => $blocked]);
}

/** Block one visitor straight from the inbox */
function cpchatAdminBlock()
{
    $admin = cpchat_require_admin();
    $b = cpchat_post_body();
    $id = isset($b['id']) ? (int) $b['id'] : 0;
    $conversation = cpchat_find_conversation('', $id);
    if (!$conversation) {
        cpchat_error('Conversation not found');
    }
    $s = cpchat_settings();
    $hours = isset($b['hours']) ? max(1, (int) $b['hours']) : $s['spam_block_hours'];
    $blocked = [];
    foreach (['ip' => $conversation->ip, 'mac' => $conversation->mac, 'phone' => $conversation->phone] as $type => $value) {
        if ($value !== '' && cpchat_block($type, $value, 'manual block by ' . $admin['username'], $hours)) {
            $blocked[] = $type;
        }
    }
    cpchat_spam_log('manual_block', 'chat #' . $id, $conversation->ip, $conversation->mac);
    cpchat_json(['success' => true, 'blocked' => $blocked, 'hours' => $hours]);
}

/** Current spam counters, used by the inbox toolbar refresh */
function cpchatAdminSpamCount()
{
    cpchat_require_admin();
    cpchat_json(['success' => true] + cpchat_spam_stats());
}

/** Feeds the navbar bell: new customer messages + counters */
function cpchatAdminPoll()
{
    cpchat_require_admin();
    $since = (int) _get('since');
    $sql = "SELECT m.id, m.conversation_id, m.sender, m.sender_name, m.body, m.created_at,
            c.name, c.phone, c.mac, c.ip, c.username, c.status
        FROM tbl_cpchat_messages m
        JOIN tbl_cpchat_conversations c ON c.id = m.conversation_id
        WHERE m.id > ? AND m.sender = 'customer'
        ORDER BY m.id ASC LIMIT 30";
    $rows = ORM::for_table('tbl_cpchat_messages')->raw_query($sql, [$since])->find_array();
    $messages = [];
    $maxId = $since;
    foreach ((array) $rows as $m) {
        $messages[] = [
            'id' => (int) $m['id'],
            'conversation_id' => (int) $m['conversation_id'],
            'body' => $m['body'],
            'at' => $m['created_at'],
            'time' => date('H:i', strtotime($m['created_at'])),
            'ago' => Lang::timeElapsed($m['created_at']),
            'name' => $m['name'],
            'phone' => $m['phone'],
            'mac' => $m['mac'],
        ];
        if ((int) $m['id'] > $maxId) {
            $maxId = (int) $m['id'];
        }
    }
    $unread = (int) ORM::for_table('tbl_cpchat_conversations')->where_gt('unread_admin', 0)->sum('unread_admin');
    $chats = (int) ORM::for_table('tbl_cpchat_conversations')->where('status', 'open')->count();
    cpchat_json([
        'success' => true,
        'messages' => $messages,
        'last_id' => $maxId,
        'unread' => $unread,
        'open_chats' => $chats,
    ]);
}

function cpchatAdminCount()
{
    cpchat_require_admin();
    $unread = (int) ORM::for_table('tbl_cpchat_conversations')->where_gt('unread_admin', 0)->sum('unread_admin');
    $chats = (int) ORM::for_table('tbl_cpchat_conversations')->where('status', 'open')->count();
    cpchat_json(['success' => true, 'unread' => $unread, 'open_chats' => $chats]);
}

/** Permanently delete a conversation with its messages (dashboard quick action) */
function cpchatAdminDelete()
{
    $admin = cpchat_require_admin();
    $b = cpchat_post_body();
    $id = isset($b['id']) ? (int) $b['id'] : 0;
    $conversation = cpchat_find_conversation('', $id);
    if (!$conversation) {
        cpchat_error('Conversation not found');
    }
    ORM::raw_execute("DELETE FROM tbl_cpchat_messages WHERE conversation_id = ?", [$id]);
    $conversation->delete();
    _log('[' . $admin['username'] . ']: Captive Portal Chat conversation #' . $id . ' deleted', $admin['user_type'], $admin['id']);
    cpchat_json(['success' => true]);
}

/* ------------------------------------------------------------------ *
 *  Export (CSV + PDF)
 * ------------------------------------------------------------------ */

/** Filter values from the query string, shared by the inbox and the exporters */
function cpchat_filters_from_request($limitSearch = 60)
{
    $status = _get('status', '');
    $assigned = _get('assigned', '');
    $spam = _get('spam', '');
    return [
        'q' => cpchat_clean_text(_get('q', ''), $limitSearch),
        'status' => ($status === 'open' || $status === 'closed') ? $status : '',
        'router' => cpchat_meta_value(_get('router', ''), 60),
        'assigned' => ($assigned === 'me' || $assigned === 'unassigned' || is_numeric($assigned)) ? $assigned : '',
        'tag' => cpchat_clean_text(_get('tag', ''), 24),
        'spam' => ($spam === '1' || $spam === 'yes'),
    ];
}

function cpchat_export_headers($filename, $mime)
{
    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    if (!headers_sent()) {
        header('Content-Type: ' . $mime . '; charset=utf-8');
        header('Content-Disposition: attachment; filename="' . basename($filename) . '"');
        header('X-Robots-Tag: noindex');
    }
}

/** CSV of the filtered chat list, or of one conversation when id > 0 */
function cpchatExportCsv()
{
    cpchat_require_admin();
    $id = (int) _get('id');
    $scope = _get('scope', '');
    $stamp = date('Ymd-His');
    if ($id > 0 && $scope !== 'list') {
        $conversation = cpchat_find_conversation('', $id);
        if (!$conversation) {
            cpchat_error('Conversation not found');
        }
        $row = $conversation->as_array();
        cpchat_export_headers('cpchat-' . $id . '-' . $stamp . '.csv', 'text/csv');
        $out = fopen('php://output', 'w');
        fwrite($out, "\xEF\xBB\xBF");
        fputcsv($out, ['# ' . $id, $row['name'], $row['phone'], $row['mac'], $row['ip'], $row['router'], $row['status'], $row['tags']]);
        fputcsv($out, ['Time', 'Sender', 'From', 'Message']);
        foreach (cpchat_thread($id) as $m) {
            fputcsv($out, [$m['at'], $m['sender'], $m['name'], $m['body']]);
        }
        fclose($out);
        exit;
    }
    $rows = cpchat_conversation_query(cpchat_filters_from_request(), 5000);
    cpchat_export_headers('cpchat-chats-' . $stamp . '.csv', 'text/csv');
    $out = fopen('php://output', 'w');
    fwrite($out, "\xEF\xBB\xBF");
    fputcsv($out, ['ID', 'Status', 'Name', 'Phone', 'MAC', 'IP', 'Username', 'Router', 'Page', 'Tags', 'Assigned', 'Close reason', 'Spam', 'Messages', 'First reply', 'Created', 'Last message', 'Last body']);
    $names = cpchat_agent_names();
    foreach ($rows as $c) {
        $assignedId = (int) $c['assigned_to'];
        fputcsv($out, [
            (int) $c['id'],
            $c['status'],
            $c['name'],
            $c['phone'],
            $c['mac'],
            $c['ip'],
            $c['username'],
            $c['router'],
            $c['page'],
            $c['tags'],
            ($assignedId > 0 && isset($names[$assignedId])) ? $names[$assignedId] : '',
            $c['close_reason'],
            (int) $c['is_spam'] ? 'yes' : 'no',
            (int) $c['msg_count'],
            $c['first_reply_at'],
            $c['created_at'],
            $c['last_message_at'],
            $c['last_body'],
        ]);
    }
    fclose($out);
    exit;
}

/** PDF: a transcript for one chat, or the filtered chat list when no id */
function cpchatExportPdf()
{
    cpchat_require_admin();
    if (!class_exists('\Mpdf\Mpdf')) {
        cpchat_error('PDF library is not available on this server');
    }
    $id = (int) _get('id');
    $scope = _get('scope', '');
    $stamp = date('Ymd-His');
    $company = isset($GLOBALS['config']['CompanyName']) ? $GLOBALS['config']['CompanyName'] : 'PHPNuxBill';
    try {
        $mpdf = new \Mpdf\Mpdf(['format' => 'A4', 'margin_left' => 12, 'margin_right' => 12, 'margin_top' => 14, 'margin_bottom' => 14]);
        $mpdf->SetTitle('Captive Portal Chat ' . ($id > 0 ? 'transcript #' . $id : 'report'));
        $mpdf->SetAuthor($company);
        $mpdf->SetFooter($company . ' | Captive Portal Chat | ' . date('Y-m-d H:i') . ' | {PAGENO}/{nbpg}');
        if ($id > 0 && $scope !== 'list') {
            $conversation = cpchat_find_conversation('', $id);
            if (!$conversation) {
                cpchat_error('Conversation not found');
            }
            $mpdf->WriteHtml(cpchat_pdf_transcript($conversation->as_array(), cpchat_thread($id), $company));
            $mpdf->Output('cpchat-' . $id . '-' . $stamp . '.pdf', 'D');
            exit;
        }
        $mpdf->WriteHtml(cpchat_pdf_list(cpchat_conversation_query(cpchat_filters_from_request(), 500), $company));
        $mpdf->Output('cpchat-chats-' . $stamp . '.pdf', 'D');
        exit;
    } catch (Throwable $e) {
        cpchat_error('Export failed: ' . $e->getMessage());
    }
}

function cpchat_pdf_head($title, $subtitle)
{
    return '<div style="font-size:15pt;font-weight:bold;color:#1a202c;">' . htmlspecialchars($title) . '</div>'
        . '<div style="font-size:9pt;color:#4a5568;margin-top:2px;">' . htmlspecialchars($subtitle) . '</div>'
        . '<div style="border-bottom:1.4pt solid #2b6cb0;margin-bottom:10pt;"></div>';
}

function cpchat_pdf_table($headings, $rows, $widths)
{
    $html = '<table width="100%" cellspacing="0" cellpadding="4" style="font-size:8pt;border-collapse:collapse;">';
    $html .= '<tr style="background:#edf2f7;color:#1a202c;font-weight:bold;">';
    foreach ($headings as $i => $h) {
        $html .= '<td width="' . $widths[$i] . '%">' . htmlspecialchars($h) . '</td>';
    }
    $html .= '</tr>';
    $shade = false;
    foreach ($rows as $row) {
        $html .= '<tr style="' . ($shade ? 'background:#f7fafc;' : '') . 'vertical-align:top;">';
        foreach ($row as $i => $cell) {
            $html .= '<td width="' . $widths[$i] . '%">' . nl2br(htmlspecialchars((string) $cell)) . '</td>';
        }
        $html .= '</tr>';
        $shade = !$shade;
    }
    return $html . '</table>';
}

/** One-page transcript with the customer details on top */
function cpchat_pdf_transcript($c, $messages, $company)
{
    $id = (int) $c['id'];
    $html = cpchat_pdf_head($company . ' - Chat transcript #' . $id, $c['name'] . ($c['phone'] !== '' ? ' / ' . $c['phone'] : '') . ' / ' . $c['mac'] . ' / ' . $c['ip']);
    $assigned = '-';
    if ((int) $c['assigned_to'] > 0) {
        $names = cpchat_agent_names();
        $assignedId = (int) $c['assigned_to'];
        $assigned = isset($names[$assignedId]) ? $names[$assignedId] : ('#' . $assignedId);
    }
    $html .= cpchat_pdf_table(
        ['Status', 'Router', 'Tags', 'Assigned', 'Close reason', 'Created', 'Last message'],
        [[
            $c['status'],
            ($c['router'] !== '' ? $c['router'] : '-'),
            ($c['tags'] !== '' ? $c['tags'] : '-'),
            $assigned,
            ($c['close_reason'] !== '' ? $c['close_reason'] : '-'),
            $c['created_at'],
            $c['last_message_at'],
        ]],
        [10, 16, 18, 14, 16, 13, 13]
    );
    $html .= '<div style="height:8pt;"></div>';
    $rows = [];
    foreach ($messages as $m) {
        $who = $m['sender'] === 'admin' ? ($m['name'] !== '' ? $m['name'] : 'Support') : ($m['sender'] === 'customer' ? $c['name'] : 'System');
        $rows[] = [date('d/m/Y H:i', strtotime($m['at'])), $who, $m['body']];
    }
    return $html . cpchat_pdf_table(['Time', 'From', 'Message'], $rows, [13, 18, 69]);
}

/** Chat list report */
function cpchat_pdf_list($rows, $company)
{
    $stats = cpchat_stats();
    $html = cpchat_pdf_head($company . ' - Captive Portal Chat report', date('Y-m-d H:i') . ' - ' . count($rows) . ' chats');
    $names = cpchat_agent_names();
    $data = [];
    foreach ($rows as $c) {
        $assignedId = (int) $c['assigned_to'];
        $data[] = [
            (int) $c['id'],
            $c['status'] . ((int) $c['is_spam'] === 1 ? ' / spam' : ''),
            $c['name'] . ($c['phone'] !== '' ? "\n" . $c['phone'] : ''),
            $c['mac'] . "\n" . $c['ip'],
            ($c['router'] !== '' ? $c['router'] : '-'),
            ($c['tags'] !== '' ? $c['tags'] : '-'),
            ($assignedId > 0 && isset($names[$assignedId])) ? $names[$assignedId] : '-',
            (int) $c['msg_count'],
            $c['last_message_at'],
        ];
    }
    $html .= cpchat_pdf_table(
        ['ID', 'Status', 'Customer', 'MAC / IP', 'Router', 'Tags', 'Assigned', 'Msg', 'Last message'],
        $data,
        [4, 9, 15, 17, 12, 14, 11, 4, 14]
    );
    $summary = 'Total chats: ' . $stats['total'] . '  |  Open: ' . $stats['open'] . '  |  Waiting for reply: ' . $stats['waiting']
        . '  |  Messages: ' . $stats['messages'] . '  |  Spam: ' . $stats['spam'];
    return $html . '<div style="font-size:8pt;color:#4a5568;margin-top:8pt;">' . htmlspecialchars($summary) . '</div>';
}

/* ------------------------------------------------------------------ *
 *  Navbar hook installer (patches the active admin header.tpl)
 * ------------------------------------------------------------------ */

function cpchatnavbar_file()
{
    global $config;
    $root = rtrim($GLOBALS['root_path'], '/\\') . DIRECTORY_SEPARATOR;
    if (!empty($config['theme']) && $config['theme'] != 'default') {
        $path = $root . 'ui' . DIRECTORY_SEPARATOR . 'themes' . DIRECTORY_SEPARATOR . $config['theme']
            . DIRECTORY_SEPARATOR . 'admin' . DIRECTORY_SEPARATOR . 'header.tpl';
        if (file_exists($path)) {
            return $path;
        }
    }
    return $root . 'ui' . DIRECTORY_SEPARATOR . 'ui' . DIRECTORY_SEPARATOR . 'admin' . DIRECTORY_SEPARATOR . 'header.tpl';
}

function cpchatnavbar_state()
{
    $file = cpchatnavbar_file();
    if (!file_exists($file)) {
        return ['status' => 'missing', 'file' => $file, 'writable' => false];
    }
    $contents = file_get_contents($file);
    return [
        'status' => (strpos($contents, 'cpchatNavbarJs') !== false) ? 'installed' : 'none',
        'file' => $file,
        'writable' => is_writeable($file),
    ];
}

function cpchatnavbar_install()
{
    $state = cpchatnavbar_state();
    if ($state['status'] === 'missing') {
        return Lang::T('Admin header template not found');
    }
    if ($state['status'] === 'installed') {
        return true;
    }
    if (!$state['writable']) {
        return Lang::T('Admin header template is not writable');
    }
    // nowdoc on purpose: {$_url} must stay literal so Smarty resolves it at render time
    $block = <<<'HTML'
    <!-- cpchat-navbar -->
    <script src="{$_url}plugin/cpchatNavbarJs" defer></script>
HTML;
    $block = $block . "\n";
    $contents = file_get_contents($state['file']);
    $lines = explode("\n", $contents);
    $patched = false;
    foreach ($lines as $i => $line) {
        if (stripos($line, '</head>') !== false) {
            array_splice($lines, $i, 0, [$block]);
            $patched = true;
            break;
        }
    }
    if (!$patched) {
        return Lang::T('Cannot find the head section of the admin template');
    }
    if (file_put_contents($state['file'], implode("\n", $lines), LOCK_EX) === false) {
        return Lang::T('Cannot write the admin template');
    }
    cpchat_clear_compiled();
    return true;
}

function cpchatnavbar_remove()
{
    $state = cpchatnavbar_state();
    if ($state['status'] !== 'installed') {
        return true;
    }
    if (!$state['writable']) {
        return Lang::T('Admin header template is not writable');
    }
    $contents = file_get_contents($state['file']);
    $contents = preg_replace('/[ \t]*<!-- cpchat-navbar -->\R[ \t]*<script[^>]*cpchatNavbarJs[^>]*><\/script>\R/i', '', $contents);
    file_put_contents($state['file'], $contents, LOCK_EX);
    cpchat_clear_compiled();
    return true;
}

/** Drop compiled admin templates so the patched header is recompiled right away */
function cpchat_clear_compiled()
{
    $dir = $GLOBALS['root_path'] . 'ui' . DIRECTORY_SEPARATOR . 'compiled' . DIRECTORY_SEPARATOR;
    foreach ((array) glob($dir . '*.header.tpl.php') as $f) {
        @unlink($f);
    }
    foreach ((array) glob($dir . '*.php') as $f) {
        if (strpos((string) file_get_contents($f), 'cpchatNavbarJs') !== false) {
            @unlink($f);
        }
    }
}

/* ------------------------------------------------------------------ *
 *  Stats for the dashboard / inbox header / diagnostics
 * ------------------------------------------------------------------ */

function cpchat_stats()
{
    if (!cpchat_ready()) {
        return [];
    }
    $today = date('Y-m-d 00:00:00');
    $week = date('Y-m-d H:i:s', time() - 7 * 86400);
    return [
        'open' => (int) ORM::for_table('tbl_cpchat_conversations')->where('status', 'open')->where('is_spam', 0)->count(),
        'closed' => (int) ORM::for_table('tbl_cpchat_conversations')->where('status', 'closed')->count(),
        'total' => (int) ORM::for_table('tbl_cpchat_conversations')->count(),
        'today' => (int) ORM::for_table('tbl_cpchat_conversations')->where_gte('created_at', $today)->count(),
        'week' => (int) ORM::for_table('tbl_cpchat_conversations')->where_gte('created_at', $week)->count(),
        'waiting' => (int) ORM::for_table('tbl_cpchat_conversations')->where('status', 'open')->where('is_spam', 0)->where_raw('(first_reply_at IS NULL OR unread_admin > 0)')->count(),
        'messages' => (int) ORM::for_table('tbl_cpchat_messages')->count(),
        'unread' => (int) ORM::for_table('tbl_cpchat_conversations')->where_gt('unread_admin', 0)->sum('unread_admin'),
        'spam' => (int) ORM::for_table('tbl_cpchat_conversations')->where('is_spam', 1)->count(),
        'avg_first_reply' => cpchat_avg_first_reply(),
    ];
}

/** Minutes between a chat starting and the first admin answer */
function cpchat_avg_first_reply()
{
    $sql = "SELECT AVG(TIMESTAMPDIFF(MINUTE, created_at, first_reply_at)) AS a
            FROM tbl_cpchat_conversations WHERE first_reply_at IS NOT NULL AND is_spam = 0";
    $row = ORM::for_table('tbl_cpchat_conversations')->raw_query($sql)->find_array();
    return isset($row[0]['a']) && $row[0]['a'] !== null ? round((float) $row[0]['a'], 1) : null;
}

/** Daily conversation + message counters for the dashboard chart */
function cpchat_stats_series($days = 14)
{
    $days = max(7, min(60, (int) $days));
    $from = date('Y-m-d 00:00:00', strtotime('-' . ($days - 1) . ' days'));
    $sql = "SELECT DATE(created_at) AS d, COUNT(*) AS n FROM tbl_cpchat_conversations
            WHERE created_at >= ? GROUP BY DATE(created_at)";
    $chats = ORM::for_table('tbl_cpchat_conversations')->raw_query($sql, [$from])->find_array();
    $sql2 = "SELECT DATE(created_at) AS d, COUNT(*) AS n FROM tbl_cpchat_messages
            WHERE created_at >= ? GROUP BY DATE(created_at)";
    $msgs = ORM::for_table('tbl_cpchat_messages')->raw_query($sql2, [$from])->find_array();
    $sql3 = "SELECT DATE(updated_at) AS d, COUNT(*) AS n FROM tbl_cpchat_conversations
            WHERE status = 'closed' AND updated_at >= ? GROUP BY DATE(updated_at)";
    $closed = ORM::for_table('tbl_cpchat_conversations')->raw_query($sql3, [$from])->find_array();
    $sql4 = "SELECT DATE(created_at) AS d, COUNT(*) AS n FROM tbl_cpchat_spamlog
            WHERE created_at >= ? GROUP BY DATE(created_at)";
    $blocked = ORM::for_table('tbl_cpchat_spamlog')->raw_query($sql4, [$from])->find_array();
    $mapChats = [];
    $mapMsgs = [];
    $mapClosed = [];
    $mapBlocked = [];
    foreach ((array) $chats as $r) {
        $mapChats[$r['d']] = (int) $r['n'];
    }
    foreach ((array) $msgs as $r) {
        $mapMsgs[$r['d']] = (int) $r['n'];
    }
    foreach ((array) $closed as $r) {
        $mapClosed[$r['d']] = (int) $r['n'];
    }
    foreach ((array) $blocked as $r) {
        $mapBlocked[$r['d']] = (int) $r['n'];
    }
    $out = [];
    for ($i = 0; $i < $days; $i++) {
        $date = date('Y-m-d', strtotime('+' . $i . ' days', strtotime($from)));
        $out[] = [
            'date' => $date,
            'label' => date('d/m', strtotime($date)),
            'chats' => isset($mapChats[$date]) ? $mapChats[$date] : 0,
            'messages' => isset($mapMsgs[$date]) ? $mapMsgs[$date] : 0,
            'closed' => isset($mapClosed[$date]) ? $mapClosed[$date] : 0,
            'blocked' => isset($mapBlocked[$date]) ? $mapBlocked[$date] : 0,
        ];
    }
    return $out;
}

/** Distinct router names, so filters and settings can offer them */
function cpchat_routers_list()
{
    if (!cpchat_ready()) {
        return [];
    }
    $rows = ORM::for_table('tbl_cpchat_conversations')
        ->raw_query("SELECT DISTINCT router FROM tbl_cpchat_conversations WHERE router <> '' ORDER BY router ASC")
        ->find_array();
    $out = [];
    foreach ((array) $rows as $r) {
        $out[] = $r['router'];
    }
    return $out;
}

/** Per hotspot-router breakdown */
function cpchat_router_stats($limit = 12)
{
    $sql = "SELECT IF(c.router = '' OR c.router IS NULL, '(unknown)', c.router) AS router,
            COUNT(*) AS chats,
            SUM(CASE WHEN c.status = 'open' THEN 1 ELSE 0 END) AS open_chats,
            SUM((SELECT COUNT(*) FROM tbl_cpchat_messages m WHERE m.conversation_id = c.id AND m.sender = 'customer')) AS msgs,
            MAX(c.last_message_at) AS last_at
        FROM tbl_cpchat_conversations c GROUP BY router ORDER BY chats DESC LIMIT " . max(1, (int) $limit);
    $rows = ORM::for_table('tbl_cpchat_conversations')->raw_query($sql)->find_array();
    return is_array($rows) ? $rows : [];
}

/** Who is handling what */
function cpchat_agent_workload($limit = 12)
{
    $sql = "SELECT u.id, u.fullname, u.username, u.user_type,
            COUNT(c.id) AS total,
            SUM(CASE WHEN c.status = 'open' THEN 1 ELSE 0 END) AS open_chats,
            SUM(c.unread_admin) AS unread
        FROM tbl_users u
        LEFT JOIN tbl_cpchat_conversations c ON c.assigned_to = u.id
        WHERE u.status = 'Active' AND u.user_type IN ('SuperAdmin','Admin')
        GROUP BY u.id ORDER BY total DESC, u.username ASC LIMIT " . max(1, (int) $limit);
    $rows = ORM::for_table('tbl_users')->raw_query($sql)->find_array();
    $out = [];
    foreach ((array) $rows as $r) {
        $out[] = [
            'id' => (int) $r['id'],
            'name' => $r['fullname'] !== '' ? $r['fullname'] : $r['username'],
            'type' => $r['user_type'],
            'total' => (int) $r['total'],
            'open_chats' => (int) $r['open_chats'],
            'unread' => (int) $r['unread'],
        ];
    }
    return $out;
}

/** Spam protection summary for the dashboard */
function cpchat_spam_stats()
{
    if (!cpchat_ready()) {
        return ['hits_24h' => 0, 'blocked' => 0, 'total' => 0, 'reasons' => []];
    }
    $from = date('Y-m-d H:i:s', time() - 86400);
    $rows = ORM::for_table('tbl_cpchat_spamlog')
        ->raw_query("SELECT reason, COUNT(*) AS n FROM tbl_cpchat_spamlog WHERE created_at >= ? GROUP BY reason ORDER BY n DESC LIMIT 6", [$from])
        ->find_array();
    $reasons = [];
    foreach ((array) $rows as $r) {
        $reasons[] = ['reason' => $r['reason'], 'n' => (int) $r['n']];
    }
    return [
        'hits_24h' => (int) ORM::for_table('tbl_cpchat_spamlog')->where_gte('created_at', $from)->count(),
        'total' => (int) ORM::for_table('tbl_cpchat_spamlog')->count(),
        'blocked' => (int) ORM::for_table('tbl_cpchat_blocked')->where_raw('(expires_at IS NULL OR expires_at > ?)', [date('Y-m-d H:i:s')])->count(),
        'reasons' => $reasons,
    ];
}

function cpchat_spamlog_list($limit = 20)
{
    if (!cpchat_ready()) {
        return [];
    }
    $rows = ORM::for_table('tbl_cpchat_spamlog')
        ->order_by_desc('id')->limit(max(1, (int) $limit))->find_array();
    return is_array($rows) ? $rows : [];
}

/** Full thread of one conversation, oldest first */
function cpchat_thread($id, $limit = 500)
{
    $rows = ORM::for_table('tbl_cpchat_messages')
        ->where('conversation_id', (int) $id)
        ->order_by_asc('id')->limit(max(1, (int) $limit))->find_array();
    return cpchat_map_messages($rows);
}
