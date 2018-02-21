<?php
include "php/build.php";
include "php/copy.php";
$buildData = array(
    # folder => rootNodeName
    'aiscripts' => 'diff',
    'index' => 'index',
    'libraries' => 'diff',
    'md' => 'diff',
    't' => 'language',
);
$currentDir = dirname(__FILE__) . '/';
foreach ($buildData as $folderName => $nodeName) {
    $sourceDir = $currentDir . $folderName . '/src/';
    $targetDir = $currentDir . $folderName . '/';
    copyFiles($sourceDir . 'add/', $targetdir);
    build($nodeName, $sourceDir, $targetDir);
}


