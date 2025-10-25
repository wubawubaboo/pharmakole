<?php
function jsonResponse($data, $status = 200){
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}


function getBearerToken(){
    $headers = apache_request_headers();
    if(!empty($headers['Authorization'])){
        if(preg_match('/Bearer\s+(.*)$/i', $headers['Authorization'], $matches)){
            return $matches[1];
        }
    }
    return null;
}