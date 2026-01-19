<?php
require_once 'config.php';
redirectIfNotLoggedIn();

$user_id = $_SESSION['user_id'];
$role = $_SESSION['role'];
$first_name = $_SESSION['first_name'];
$last_name = $_SESSION['last_name'];

// Je nach Rolle zum entsprechenden Dashboard weiterleiten
$redirect_map = [
    'Admin' => 'admin/dashboard.php',
    'HR' => 'hr/dashboard.php',
    'Abteilungsleiter' => 'workflow/approve.php',
    'Chef' => 'workflow/approve.php',
    'IT' => 'workflow/approve.php'
];

$redirect_url = $redirect_map[$role] ?? 'workflow/dashboard.php';
header('Location: ' . SITE_URL . $redirect_url);
exit();
?>
