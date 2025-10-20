<?php
require_once __DIR__.'/../../helpers.php';
require_once __DIR__.'/../../auth.php';
require_once __DIR__.'/../../logger.php';
class ReportsController{
private $pdo; 
private $model;

public function __construct(){
$cfg = include __DIR__.'/../../../config/config.php';
$dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4";
$this->pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
require_once __DIR__.'/ReportsModel.php';$this->model = new ReportsModel($this->pdo);
ActivityLogger::init($this->pdo);
}
public function handle($method, $get, $post, $body){
authenticate();
$path = $_SERVER['REQUEST_URI'];
if($method === 'GET' && strpos($path, '/api/reports/daily') !== false){
    $date = $_GET['date'] ?? date('Y-m-d');
    $r = $this->model->dailySales($date);
    jsonResponse(['date'=>$date,'sales'=>$r]);
}
if($method === 'GET' && strpos($path, '/api/reports/summary') !== false){
    $start = $_GET['start'] ?? date('Y-m-01'); $end = $_GET['end'] ?? date('Y-m-d');
    $r = $this->model->salesSummary($start, $end);
    jsonResponse(['start'=>$start,'end'=>$end,'summary'=>$r]);
}
if($method === 'GET' && strpos($path, '/api/reports/profitloss') !== false){
    $start = $_GET['start'] ?? date('Y-m-01'); $end = $_GET['end'] ?? date('Y-m-d');
    $r = $this->model->profitLoss($start, $end);
    jsonResponse(['start'=>$start,'end'=>$end,'profitloss'=>$r]);
}
if($method === 'GET' && strpos($path, '/api/reports/adjustments') !== false){
    $r = $this->model->listAdjustments();
    jsonResponse(['data'=>$r]);
}
if($method === 'GET' && strpos($path, '/api/reports/activity') !== false){
        $r = $this->model->listActivityLogs();
        jsonResponse(['data'=>$r]);
    }
if($method === 'GET' && strpos($path, '/api/reports/transactions') !== false){
    $start = $_GET['start'] ?? date('Y-m-d');
    $end = $_GET['end'] ?? date('Y-m_d');
    $product_id = $_GET['product_id'] ?? null;
    
    $r = $this->model->getSalesTransactions($start, $end, $product_id);
    jsonResponse(['data'=>$r]);
    return;
}
jsonResponse(['error'=>'Endpoint not found'],404);
}
}