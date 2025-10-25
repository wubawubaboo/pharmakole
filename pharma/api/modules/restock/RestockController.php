<?php
require_once __DIR__ . '/../../helpers.php';
require_once __DIR__ . '/../../auth.php';

class RestockController {
    private $pdo;
    private $model;

    public function __construct() {
        $cfg = include __DIR__ . '/../../../config/config.php';
        $dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4";
        $this->pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        require_once __DIR__ . '/RestockModel.php';
        $this->model = new RestockModel($this->pdo);
    }

    public function handle($method, $get, $post, $body) {
        authenticate();
        $path = $_SERVER['REQUEST_URI'];

        if ($method === 'POST' && strpos($path, '/api/restock/receive') !== false) {
            $data = json_decode($body, true);
            if (empty($data['supplier']) || empty($data['items']) || !is_array($data['items'])) {
                 jsonResponse(['error' => 'Invalid payload. "supplier" and "items" array are required.'], 400);
                 return;
            }
            $id = $this->model->receiveStock($data);
            jsonResponse(['success' => true, 'receipt_id' => $id]);
            return;
        }

        if ($method === 'GET' && strpos($path, '/api/restock/list') !== false) {
            $r = $this->model->listReceipts();
            jsonResponse(['data' => $r]);
            return;
        }

        if ($method === 'GET' && strpos($path, '/api/restock/details') !== false) {
            $id = $get['id'] ?? 0;
            if (empty($id)) {
                jsonResponse(['error' => 'Receipt ID is required.'], 400);
                return;
            }
            $r = $this->model->getReceiptDetails($id);
            jsonResponse($r);
            return;
        }

        jsonResponse(['error' => 'Endpoint not found'], 404);
    }
}
?>