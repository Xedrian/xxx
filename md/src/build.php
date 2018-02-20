<?php
include "../../php/build.php";
include "../../php/copy.php";
build("diff", $currentDir = dirname(__FILE__) . "/", $targetdir = dirname($currentDir) . "/");
copyFiles($currentDir . 'add/', $targetdir);