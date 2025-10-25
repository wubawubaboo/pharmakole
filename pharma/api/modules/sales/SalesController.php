<?php

require_once __DIR__ . '/../../helpers.php';
require_once __DIR__ . '/../../auth.php';
require_once __DIR__ . '/../../logger.php';

class SalesController
{
    private $pdo;
    private $model;
    private $cfg;

    public function __construct()
    {
        $this->cfg = include __DIR__ . '/../../../config/config.php';
        $dsn = "mysql:host={$this->cfg['db']['host']};dbname={$this->cfg['db']['dbname']};charset=utf8mb4";
        $this->pdo = new PDO($dsn, $this->cfg['db']['user'], $this->cfg['db']['pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);
        require_once __DIR__ . '/SalesModel.php';
        $this->model = new SalesModel($this->pdo);
        ActivityLogger::init($this->pdo);
    }

    public function handle($method, $get, $post, $body)
    {
        authenticate();
        $path = $_SERVER['REQUEST_URI'];

        if ($method === 'POST' && strpos($path, '/api/sales/create') !== false) {
            $data = json_decode($body, true);
            $cashier_name = $data['cashier'] ?? 'Cashier';

            $subtotal = 0;
            foreach ($data['items'] as &$it) {
                $unit_price = floatval($it['unit_price']);
                $quantity = intval($it['quantity']);
                $it['total_price'] = $quantity * $unit_price;
                $subtotal += $it['total_price'];
            }

            $discount = 0;
            $senior_flag = !empty($data['senior']) || !empty($data['pwd']);
            if ($senior_flag) {
                $discount = $subtotal * $this->cfg['senior_pwd_discount'];
            }

            $tax = ($subtotal - $discount) * $this->cfg['tax_rate'];
            $total = ($subtotal - $discount) + $tax;

            $sale = [
                'cashier' => $cashier_name,
                'total' => round($total, 2),
                'tax' => round($tax, 2),
                'discount' => round($discount, 2),
                'senior' => $senior_flag ? 1 : 0,
                'items' => $data['items'],
            ];

            $sale_id = $this->model->createSale($sale);

            if ($sale_id) {
                ActivityLogger::log('create_sale', 'Created Sale ID: ' . $sale_id . ' (Total: ' . $total . ')', $cashier_name);
                jsonResponse(['success' => true, 'sale_id' => $sale_id]);
            }

            jsonResponse(['error' => 'Failed to create sale in database.'], 500);
        }

        if ($method === 'GET' && strpos($path, '/api/sales/search') !== false) {
            $q = $_GET['q'] ?? '';
            $r = $this->model->searchTransactions($q);
            jsonResponse(['results' => $r]);
        }

        jsonResponse(['error' => 'Endpoint not found'], 404);
    }
}