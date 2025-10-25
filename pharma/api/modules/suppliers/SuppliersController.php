<?php
require_once __DIR__ . '/../../helpers.php';
require_once __DIR__ . '/../../auth.php';

class SuppliersController {
    private $pdo;
    private $model;

    public function __construct() {
        $cfg = include __DIR__ . '/../../../config/config.php';
        $dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4";
        $this->pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        require_once __DIR__ . '/SuppliersModel.php';
        $this->model = new SuppliersModel($this->pdo);
    }

    public function handle($method, $get, $post, $body) {
        authenticate();
        $path = $_SERVER['REQUEST_URI'];

        // /api/suppliers/list
        if ($method === 'GET' && strpos($path, '/api/suppliers/list') !== false) {
            $q = $get['q'] ?? '';
            $r = $this->model->listSuppliers($q);
            jsonResponse(['data' => $r]);
            return;
        }

        // /api/suppliers/create
        if ($method === 'POST' && strpos($path, '/api/suppliers/create') !== false) {
            $data = json_decode($body, true);
            if (empty($data['name'])) {
                 jsonResponse(['error' => 'Supplier name is required.'], 400);
                 return;
            }
            $id = $this->model->createSupplier($data);
            jsonResponse(['success' => true, 'id' => $id]);
            return;
        }

        // /api/suppliers/update
        if ($method === 'POST' && strpos($path, '/api/suppliers/update') !== false) {
            $data = json_decode($body, true);
            $id = $data['id'] ?? 0;
            if (empty($id) || empty($data['name'])) {
                jsonResponse(['error' => 'Missing required fields (id, name).'], 400);
                return;
            }
            $this->model->updateSupplier($id, $data);
            jsonResponse(['success' => true, 'id' => $id]);
            return;
        }

        // /api/suppliers/delete
        if ($method === 'POST' && strpos($path, '/api/suppliers/delete') !== false) {
            $data = json_decode($body, true);
            $id = $data['id'] ?? 0;
            if (empty($id)) {
                jsonResponse(['error' => 'Supplier ID is required.'], 400);
                return;
            }
            $this->model->deleteSupplier($id);
            jsonResponse(['success' => true]);
            return;
        }

        jsonResponse(['error' => 'Endpoint not found'], 404);
    }
}
?>