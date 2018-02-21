<?php
include "php/build.php";
include "php/copy.php";
$buildData = array(
	# folder => rootNodeName
	'aiscripts' => 'diff',
	'index' => 'diff',
	'libraries' => 'diff',
	'md' => 'diff',
	't' => 'language',
);
$currentDir = dirname(__FILE__) . '/';
foreach ($buildData as $folderName => $nodeName) {
	$sourceDir = $currentDir . $folderName . '/src/';
	$targetDir = $currentDir . $folderName . '/';
	build($nodeName, $sourceDir, $targetDir);
	copyFiles($sourceDir . 'add/', $targetDir);
}


