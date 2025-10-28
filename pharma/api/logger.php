<?php
class ActivityLogger {
    private static $pdo;
    public static function init($pdo) {
        self::$pdo = $pdo;
    }

    public static function log($action, $details = '', $username = 'system') {
        if (!self::$pdo) {
            return;
        }

        try {
            $sql = "INSERT INTO activity_logs (username, action, details, created_at) 
                    VALUES (:user, :action, :details, NOW())";
            $stmt = self::$pdo->prepare($sql);
            $stmt->execute([
                ':user' => $username,
                ':action' => $action,
                ':details' => $details
            ]);
        } catch (Exception $e) {
            $log_file = __DIR__ . '/../../storage/logs/logger_errors.log';
            $error_message = date('Y-m-d H:i:s') . " | Failed to log action: " . $e->getMessage() . "\n";
            file_put_contents($log_file, $error_message, FILE_APPEND);
        }
    }
}
?>